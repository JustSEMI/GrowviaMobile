import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../data/workspace_models.dart';
import '../ui/components.dart';
import '../ui/management_components.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ProtectedManagementState<ActivityPage> {
  @override
  AppController get controller => widget.controller;
  @override
  bool get adminOnly => true;
  final q = TextEditingController(),
      from = TextEditingController(),
      to = TextEditingController();
  String action = '',
      appliedQ = '',
      appliedAction = '',
      appliedFrom = '',
      appliedTo = '';
  Map<String, String> actions = {};
  ApiPage<ActivityEntry>? result;
  bool loading = false;
  int readGeneration = 0;
  ManagementFailure? loadFailure;
  @override
  void initializeProtected() {
    load();
  }

  @override
  void clearPrivateData() {
    readGeneration++;
    result = null;
    actions = {};
    q.clear();
    from.clear();
    to.clear();
    loadFailure = null;
  }

  bool validDate(String text) {
    if (text.isEmpty) return true;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return false;
    final parsed = DateTime.tryParse('${text}T00:00:00Z');
    return parsed != null && parsed.toIso8601String().substring(0, 10) == text;
  }

  void apply() {
    final errors = <String, List<String>>{};
    if (!validDate(from.text.trim())) {
      errors['from'] = ['Gunakan tanggal valid YYYY-MM-DD.'];
    }
    if (!validDate(to.text.trim())) {
      errors['to'] = ['Gunakan tanggal valid YYYY-MM-DD.'];
    }
    if (errors.isEmpty &&
        from.text.isNotEmpty &&
        to.text.isNotEmpty &&
        from.text.trim().compareTo(to.text.trim()) > 0) {
      errors['to'] = ['Tanggal akhir tidak boleh sebelum tanggal awal.'];
    }
    setState(() {
      failure = errors.isEmpty
          ? null
          : ManagementFailure('Filter belum diterapkan.', errors);
    });
    if (errors.isNotEmpty) return;
    appliedQ = q.text.trim();
    appliedAction = action;
    appliedFrom = from.text.trim();
    appliedTo = to.text.trim();
    load();
  }

  Future<void> load([int page = 1]) async {
    if (!authorized) return;
    final ticket = generation, read = ++readGeneration;
    setState(() {
      loading = true;
      loadFailure = null;
      result = null;
    });
    try {
      final next = await controller.loadActivities(
        q: appliedQ,
        action: appliedAction,
        from: appliedFrom,
        to: appliedTo,
        page: page,
      );
      if (current(ticket) && read == readGeneration) {
        setState(() {
          result = next;
          actions = next.actions;
        });
      }
    } catch (error) {
      if (current(ticket) && read == readGeneration) {
        setState(() {
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

  Widget activityCard(ActivityEntry entry) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(entry.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Oleh: ${entry.actorName}'),
        if (entry.subjectName != null) Text('Subjek: ${entry.subjectName}'),
        if (entry.fields.isNotEmpty) Text('Kolom: ${entry.fields.join(', ')}'),
        const SizedBox(height: 8),
        Text(utcLabel(entry.createdAt)),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => protectedPage(
    'Aktivitas',
    () => [
      const PageIntro(
        eyebrow: 'Administrasi',
        title: 'Jejak aktivitas',
        description: 'Ringkasan tindakan dan label kolom, tanpa nilai rahasia. Zona waktu: UTC.',
      ),
      ...feedback,
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ManagementField(
              id: 'activity-q',
              label: 'Cari aktivitas',
              controller: q,
              error: failure?.field('q') ?? loadFailure?.field('q'),
            ),
            ManagementSelector(
              id: 'activity-action',
              label: 'Tindakan',
              value: action,
              options: {'': 'Semua tindakan', ...actions},
              onChanged: (v) => setState(() {
                action = v;
              }),
            ),
            ManagementField(
              id: 'activity-from',
              label: 'Dari tanggal (UTC)',
              hint: 'YYYY-MM-DD, misalnya 2026-09-01',
              controller: from,
              keyboard: TextInputType.datetime,
              error: failure?.field('from') ?? loadFailure?.field('from'),
            ),
            ManagementField(
              id: 'activity-to',
              label: 'Sampai tanggal (UTC)',
              hint: 'YYYY-MM-DD; kosongkan untuk tanpa batas.',
              controller: to,
              keyboard: TextInputType.datetime,
              error: failure?.field('to') ?? loadFailure?.field('to'),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  key: const Key('activity-apply'),
                  onPressed: loading ? null : apply,
                  child: const Text('Terapkan filter'),
                ),
                TextButton(
                  key: const Key('activity-reset'),
                  onPressed: loading
                      ? null
                      : () {
                          setState(() {
                            q.clear();
                            from.clear();
                            to.clear();
                            action = '';
                          });
                          apply();
                        },
                  child: const Text('Reset filter'),
                ),
              ],
            ),
          ],
        ),
      ),
      if (loading)
        const LinearProgressIndicator(semanticsLabel: 'Memuat aktivitas'),
      if (loadFailure != null)
        ManagementError(failure: loadFailure!, retry: () => load()),
      if (result != null) ...[
        if (result!.data.isEmpty)
          const Notice(
            title: 'Belum ada aktivitas',
            message: 'Tidak ada aktivitas yang cocok. Ubah filter atau coba lagi nanti.',
          ),
        ManagementPagination(
          page: result!.currentPage,
          lastPage: result!.lastPage,
          total: result!.total,
          onPage: load,
          busy: loading,
        ),
        ...result!.data.map(activityCard),
      ],
    ],
  );
  @override
  void dispose() {
    q.dispose();
    from.dispose();
    to.dispose();
    super.dispose();
  }
}
