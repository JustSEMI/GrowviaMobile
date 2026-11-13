import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_controller.dart';
import '../data/workspace_models.dart';
import '../ui/components.dart';
import '../ui/growvia_components.dart';
import '../ui/growvia_icon.dart';
import '../ui/management_components.dart';

const _scheduleLabels = {
  'off': 'Nonaktif',
  'daily': 'Harian',
  'every': 'Interval',
};
const _formatMime = {
  'sql': 'application/sql',
  'sql.gz': 'application/gzip',
  'tgz': 'application/gzip',
};

String _formatSize(int size) {
  if (size >= 1024 * 1024) {
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(size / 1024).toStringAsFixed(1)} KB';
}

String _formatScheduleLabel(String schedule) {
  if (schedule.startsWith('daily@')) {
    return 'Harian pada ${schedule.substring(6)} UTC';
  }
  if (schedule.startsWith('every:')) {
    return 'Setiap ${schedule.substring(6)} detik';
  }
  return 'Nonaktif';
}

String _downloadName(BackupFile file, String format) =>
    file.name.replaceFirst('.sql', '.$format');

class BackupPage extends StatefulWidget {
  const BackupPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ProtectedManagementState<BackupPage> {
  @override
  AppController get controller => widget.controller;
  @override
  bool get adminOnly => true;

  BackupData? data;
  ManagementFailure? loadFailure;
  bool loading = false;
  int readGeneration = 0;
  String mode = 'off';
  String downloadFormat = 'sql';
  final time = TextEditingController();
  final interval = TextEditingController();
  final keepDays = TextEditingController();

  @override
  void initializeProtected() {
    load();
  }

  @override
  void clearPrivateData() {
    readGeneration++;
    data = null;
    loadFailure = null;
    mode = 'off';
    for (final field in [time, interval, keepDays]) {
      field.clear();
    }
  }

  void _apply(BackupData next) {
    data = next;
    final raw = next.schedule;
    if (raw.startsWith('daily@')) {
      mode = 'daily';
      time.text = raw.substring(6);
    } else if (raw.startsWith('every:')) {
      mode = 'every';
      interval.text = raw.substring(6);
    } else {
      mode = 'off';
    }
    keepDays.text = next.keepDays;
  }

  Future<void> load() async {
    if (!authorized) return;
    final ticket = generation, read = ++readGeneration;
    setState(() {
      loading = true;
      loadFailure = null;
    });
    try {
      final next = await controller.loadBackups();
      if (!current(ticket) || read != readGeneration) return;
      setState(() => _apply(next));
    } catch (error) {
      if (current(ticket) && read == readGeneration) {
        setState(() {
          data = null;
          loadFailure = ManagementFailure.from(error);
        });
      }
    } finally {
      if (current(ticket) && read == readGeneration) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> saveSchedule() async {
    final errors = <String, List<String>>{};
    final schedule = switch (mode) {
      'daily' when time.text.trim().isEmpty => '',
      'daily' => RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time.text.trim())
          ? 'daily@${time.text.trim()}'
          : null,
      'every' => () {
        final value = int.tryParse(interval.text.trim());
        if (value == null || value < 60 || value > 999999) return null;
        return 'every:$value';
      }(),
      _ => '',
    };
    if (mode == 'daily' && schedule == null) {
      errors['backup_time'] = ['Gunakan format jam 24 jam, contoh 02:30.'];
    }
    if (mode == 'every' && schedule == null) {
      errors['backup_interval'] = ['Interval harus 60-999999 detik.'];
    }
    final keep = int.tryParse(keepDays.text.trim());
    if (keep == null || keep < 1 || keep > 90) {
      errors['backup_keep_days'] = ['Umur simpan harus 1-90 hari.'];
    }
    if (errors.isNotEmpty) {
      setState(() {
        failure = ManagementFailure('Jadwal belum disimpan.', errors);
        receipt = null;
      });
      return;
    }
    if (await write(
      () => controller.saveSystemSettings('backup', {
        'backup_schedule': schedule,
        'backup_keep_days': keep,
      }),
      'Jadwal backup disimpan di server.',
    )) {
      await load();
    }
  }

  Future<void> runNow() async {
    if (await write(
      () => controller.createBackup(),
      'Backup dibuat dan tersimpan di server.',
    )) {
      await load();
    }
  }

  Future<void> remove(BuildContext context, BackupFile file) async {
    final approved = await confirmManagement(
      context,
      title: 'Hapus berkas backup',
      message:
          'Hapus ${file.name}? Berkas cadangan ini tidak bisa dikembalikan.',
      confirm: 'Hapus',
    );
    if (!approved || !mounted) return;
    if (await write(
      () => controller.deleteBackup(file.name),
      'Berkas backup dihapus.',
    )) {
      await load();
    }
  }

  Future<void> download(BuildContext buttonContext, BackupFile file) async {
    if (busy) return;
    final ticket = generation;
    final box = buttonContext.findRenderObject() as RenderBox?;
    setState(() {
      busy = true;
      failure = null;
      receipt = null;
    });
    try {
      final bytes = await controller.downloadBackup(file.name, downloadFormat);
      if (!current(ticket)) return;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: file.name,
          files: [
            XFile.fromData(
              Uint8List.fromList(bytes),
              mimeType: _formatMime[downloadFormat] ?? 'application/octet-stream',
            ),
          ],
          fileNameOverrides: [_downloadName(file, downloadFormat)],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
          downloadFallbackEnabled: true,
        ),
      );
      if (!current(ticket)) return;
      setState(() {
        receipt = result.status == ShareResultStatus.dismissed
            ? 'Unduhan dibatalkan.'
            : 'Berkas ${_downloadName(file, downloadFormat)} disiapkan. Penyimpanan akhir mengikuti aplikasi tujuan yang kamu pilih.';
      });
    } catch (error) {
      if (current(ticket)) {
        setState(() {
          failure = ManagementFailure.from(error);
        });
      }
    } finally {
      if (current(ticket)) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Widget _statusBadge() {
    final status = data?.state.lastStatus;
    return switch (status) {
      'ok' => const GrowviaBadge('Sehat', tone: 'green'),
      'failed' => const GrowviaBadge('Gagal', tone: 'red'),
      'running' => const GrowviaBadge('Berjalan', tone: 'amber'),
      _ => const GrowviaBadge('Belum ada'),
    };
  }

  @override
  Widget build(BuildContext context) => protectedPage(
    'Backup database',
    () => [
      const PageIntro(
        eyebrow: 'Administrasi',
        title: 'Cadangan database',
        description:
            'Jadwal dump database, status terakhir, dan berkas cadangan yang bisa diunduh dalam beberapa format.',
      ),
      ...feedback,
      if (loading)
        const LinearProgressIndicator(semanticsLabel: 'Memuat backup'),
      if (loadFailure != null) ManagementError(failure: loadFailure!, retry: load),
      if (data != null) ...[
        GrowviaSectionHeading(eyebrow: 'Penjadwalan', title: 'Jadwal backup'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              managementHeading(context, 'Atur jadwal otomatis'),
              ManagementSelector(
                id: 'backup-mode',
                label: 'Mode jadwal',
                value: mode,
                options: _scheduleLabels,
                enabled: !busy && !loading,
                onChanged: (v) => setState(() {
                  mode = v;
                  failure = null;
                  receipt = null;
                }),
              ),
              if (mode == 'daily')
                ManagementField(
                  id: 'backup-time',
                  label: 'Jam backup (UTC)',
                  controller: time,
                  enabled: !busy && !loading,
                  error: failure?.field('backup_time'),
                  hint: 'Format 24 jam, contoh 02:30.',
                ),
              if (mode == 'every')
                ManagementField(
                  id: 'backup-interval',
                  label: 'Interval (detik)',
                  controller: interval,
                  enabled: !busy && !loading,
                  error: failure?.field('backup_interval'),
                  keyboard: const TextInputType.numberWithOptions(),
                  hint: 'Minimum 60 detik.',
                ),
              ManagementField(
                id: 'backup-keep-days',
                label: 'Simpan berapa hari',
                controller: keepDays,
                enabled: !busy && !loading,
                error: failure?.field('backup_keep_days'),
                keyboard: const TextInputType.numberWithOptions(),
                hint: 'Berkas lebih tua dari umur ini dihapus otomatis (1-90).',
              ),
              FilledButton(
                key: const Key('backup-schedule-save'),
                onPressed: busy || loading ? null : saveSchedule,
                child: const Text('Simpan jadwal'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GrowviaSectionHeading(eyebrow: 'Status', title: 'Backup terakhir'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatScheduleLabel(data!.schedule),
                      softWrap: true,
                    ),
                  ),
                  _statusBadge(),
                ],
              ),
              const SizedBox(height: 12),
              Text('Terakhir dijalankan: ${data!.state.lastRun ?? 'belum pernah'}'),
              if (data!.state.lastFile != null)
                Text('Berkas terakhir: ${data!.state.lastFile}'),
              if (data!.state.lastError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    data!.state.lastError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('backup-run'),
                onPressed: busy || loading ? null : runNow,
                icon: const GrowviaIcon('refresh'),
                label: const Text('Buat backup sekarang'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GrowviaSectionHeading(
          eyebrow: 'Berkas',
          title: 'Cadangan tersimpan (${data!.files.length})',
        ),
        ManagementSelector(
          id: 'backup-format',
          label: 'Format unduhan',
          value: downloadFormat,
          options: {
            for (final format in data!.formats) format: '.$format',
          },
          enabled: !busy && !loading,
          onChanged: (v) => setState(() {
            downloadFormat = v;
          }),
        ),
        if (data!.files.isEmpty)
          const Notice(
            title: 'Belum ada berkas',
            message:
                'Jalankan backup manual atau nyalakan jadwalnya, berkas cadangan muncul di sini.',
          )
        else
          ...data!.files.map(
            (file) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        file.name,
                        key: Key('backup-file-${file.name}'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('${_formatSize(file.size)} · ${file.createdAt} UTC'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton(
                            key: Key('backup-download-${file.name}'),
                            onPressed: busy || loading
                                ? null
                                : () => download(context, file),
                            child: Text('Unduh .$downloadFormat'),
                          ),
                          OutlinedButton(
                            key: Key('backup-delete-${file.name}'),
                            onPressed: busy || loading
                                ? null
                                : () => remove(context, file),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        const Text(
          'Format .sql adalah berkas master; .sql.gz dan .tgz dikonversi saat diunduh. Berkas juga tersimpan otomatis di server lewat penjadwal.',
        ),
      ],
    ],
  );

  @override
  void dispose() {
    for (final field in [time, interval, keepDays]) {
      field.dispose();
    }
    super.dispose();
  }
}
