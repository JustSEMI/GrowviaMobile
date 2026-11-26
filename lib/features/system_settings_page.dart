import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/tokens.dart';
import '../ui/components.dart';
import '../ui/growvia_components.dart';
import '../ui/growvia_icon.dart';
import '../ui/management_components.dart';

// Label mengikuti bagian di `resources/views/settings.blade.php`.
const _sectionOrder = ['general', 'climate', 'soil', 'notifications'];

const _sections = {
  'general': 'Koneksi & interval',
  'climate': 'Ambang iklim',
  'soil': 'Tanah & pompa',
  'notifications': 'Preferensi notifikasi',
};

const _sectionMeta = <
    String,
    ({
      String eyebrow,
      String title,
      String subtitle,
      String icon,
      String tone,
      String badge,
      String saveLabel,
    })>{
  'general': (
    eyebrow: '04 · Node & koneksi',
    title: 'Koneksi & Broker MQTT',
    subtitle:
        'Atur interval pembaruan telemetri. Host dan kredensial broker MQTT tetap diatur dari panel web.',
    icon: 'connection',
    tone: 'amber',
    badge: 'Web & API',
    saveLabel: 'Simpan koneksi',
  ),
  'climate': (
    eyebrow: '05 · Device 1',
    title: 'Ambang iklim',
    subtitle: 'Sesuaikan target suhu dan kelembapan udara kebunmu.',
    icon: 'sun',
    tone: 'green',
    badge: 'Device 1',
    saveLabel: 'Simpan ambang iklim',
  ),
  'soil': (
    eyebrow: '06 · Device 2',
    title: 'Tanah & pompa',
    subtitle: 'Atur batas siram otomatis, pengaman tandon, dan mode pompa.',
    icon: 'drop',
    tone: 'blue',
    badge: 'Device 2',
    saveLabel: 'Simpan tanah & pompa',
  ),
  'notifications': (
    eyebrow: '07 · Pemberitahuan',
    title: 'Preferensi notifikasi',
    subtitle:
        'Pilihan pemicu peringatan tersimpan di server; push perangkat belum aktif.',
    icon: 'info',
    tone: 'amber',
    badge: 'Belum aktif',
    saveLabel: 'Simpan notifikasi',
  ),
};

const _fieldHints = <String, String>{
  'update_interval': 'Rentang 5–300 detik untuk interval sinkronisasi node.',
  'pump_mode':
      'Mode manual menyimpan konfigurasi; kontrol langsung ada di detail node.',
  'notif_pompa': 'Pemberitahuan saat pompa menyala atau berhenti.',
  'notif_tandon': 'Pemberitahuan saat level tandon melewati batas minimum.',
  'notif_offline': 'Preferensi peringatan ketika node tidak mengirim data.',
};

const _fields = {
  'general': {'update_interval': 'Interval pembaruan (detik)'},
  'climate': {
    'th_suhu_min': 'Suhu minimum (°C)',
    'th_suhu_max': 'Suhu maksimum (°C)',
    'th_hum_min': 'Kelembapan minimum (%)',
    'th_hum_max': 'Kelembapan maksimum (%)',
  },
  'soil': {
    'soil_on': 'Mulai menyiram di bawah (%)',
    'soil_off': 'Berhenti menyiram di atas (%)',
    'tank_min': 'Isi minimum tandon (%)',
    'pump_max_run': 'Durasi maksimum (menit)',
    'pump_mode': 'Mode pompa',
  },
  'notifications': {
    'notif_pompa': 'Perubahan status pompa',
    'notif_tandon': 'Persediaan air rendah',
    'notif_offline': 'Node tidak terhubung',
  },
};

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({
    required this.controller,
    this.initialSection = 'general',
    this.embedded = false,
    this.active = true,
    super.key,
  });
  final AppController controller;
  final String initialSection;
  final bool embedded;
  final bool active;
  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState
    extends ProtectedManagementState<SystemSettingsPage> {
  @override
  AppController get controller => widget.controller;
  @override
  bool get adminOnly => true;
  final fields = <String, TextEditingController>{
    for (final section in _fields.values)
      for (final key in section.keys) key: TextEditingController(),
  };
  final _sectionKeys = {for (final id in _sectionOrder) id: GlobalKey()};
  Map<String, String>? saved;
  ManagementFailure? loadFailure;
  bool loading = false;
  int readGeneration = 0;
  bool _scrolledInitial = false;

  @override
  void initializeProtected() {
    if (widget.active) load();
  }

  @override
  void didUpdateWidget(covariant SystemSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active &&
        widget.active &&
        authorized &&
        saved == null &&
        !loading &&
        loadFailure == null) {
      load();
    }
  }

  @override
  void clearPrivateData() {
    readGeneration++;
    saved = null;
    loadFailure = null;
    for (final field in fields.values) {
      field.clear();
    }
  }

  Future<void> load() async {
    if (!authorized) return;
    final ticket = generation, read = ++readGeneration;
    setState(() {
      loading = true;
      loadFailure = null;
    });
    try {
      final next = await controller.loadSystemSettings();
      if (!current(ticket) || read != readGeneration) return;
      // Jangan membuat nilai default buatan jika respons server belum lengkap.
      if (fields.keys.any((key) => !next.containsKey(key))) {
        setState(() {
          saved = null;
          loadFailure = const ManagementFailure(
            'Konfigurasi server tidak lengkap. Muat ulang sebelum mengubah pengaturan.',
          );
        });
      } else {
        setState(() {
          saved = Map.of(next);
          for (final key in fields.keys) {
            fields[key]!.text = next[key]!;
          }
        });
        if (!widget.embedded &&
            !_scrolledInitial &&
            widget.initialSection != 'general' &&
            _sectionKeys.containsKey(widget.initialSection)) {
          _scrolledInitial = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _sectionKeys[widget.initialSection]?.currentContext;
            if (mounted && ctx != null) {
              Scrollable.ensureVisible(
                ctx,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
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

  Future<void> saveSection(String target) async {
    final errors = <String, List<String>>{};
    final values = <String, dynamic>{};
    for (final key in _fields[target]!.keys) {
      final value = fields[key]!.text.trim();
      if (key == 'pump_mode') {
        if (!['auto', 'manual'].contains(value)) {
          errors[key] = ['Pilih mode pompa yang valid.'];
        }
        values[key] = value;
      } else if (key.startsWith('notif_')) {
        if (!['0', '1'].contains(value)) {
          errors[key] = ['Pilih status notifikasi.'];
        }
        values[key] = value == '1';
      } else {
        final number = num.tryParse(value);
        if (number == null || !number.isFinite) {
          errors[key] = ['Masukkan angka yang valid.'];
          continue;
        }
        if (['update_interval', 'pump_max_run'].contains(key) &&
            int.tryParse(value) == null) {
          errors[key] = ['Gunakan bilangan bulat.'];
        }
        if (key == 'update_interval' && (number < 5 || number > 300)) {
          errors[key] = ['Interval harus 5–300 detik.'];
        }
        if (key == 'pump_max_run' && (number < 1 || number > 120)) {
          errors[key] = ['Durasi harus 1–120 menit.'];
        }
        if ([
              'th_hum_min',
              'th_hum_max',
              'soil_on',
              'soil_off',
              'tank_min',
            ].contains(key) &&
            (number < 0 || number > 100)) {
          errors[key] = ['Persentase harus 0–100.'];
        }
        values[key] = number;
      }
    }
    final minMaxPairs = switch (target) {
      'climate' => [
        ['th_suhu_min', 'th_suhu_max'],
        ['th_hum_min', 'th_hum_max'],
      ],
      'soil' => [
        ['soil_on', 'soil_off'],
      ],
      _ => const <List<String>>[],
    };
    for (final pair in minMaxPairs) {
      if (values[pair[0]] is num &&
          values[pair[1]] is num &&
          (values[pair[0]] as num) >= (values[pair[1]] as num)) {
        errors[pair[0]] = [
          'Ambang minimum/mulai harus lebih kecil dari maksimum/berhenti.',
        ];
      }
    }
    if (errors.isNotEmpty) {
      setState(() {
        failure = ManagementFailure('Pengaturan belum disimpan.', errors);
        receipt = null;
      });
      return;
    }
    if (await write(
      () => controller.saveSystemSettings(target, values),
      'Konfigurasi ${_sections[target]} disimpan di server. Ini bukan konfirmasi penerapan ke perangkat; tidak ada perintah perangkat dikirim.',
    )) {
      await load();
    }
  }

  Widget input(String key, String label) {
    final hint = _fieldHints[key];
    final t = GrowviaTokens.of(context);
    if (key == 'pump_mode') {
      final mode = fields[key]!.text;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 300 || scale > 1.35;
              Widget option(String val, String text) {
                final active = mode == val;
                return Semantics(
                  button: true,
                  selected: active,
                  child: Material(
                    color: active ? t.paleGreen : t.soft,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key('setting-pump_mode-option-$val'),
                      onTap: busy || loading
                          ? null
                          : () => setState(() => fields[key]!.text = val),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active ? t.green : t.line,
                            width: active ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (active) ...[
                              GrowviaIcon('check', size: 15, color: t.green),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active ? t.green : t.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    option('auto', 'Otomatis'),
                    const SizedBox(height: 8),
                    option('manual', 'Manual'),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: option('auto', 'Otomatis')),
                  const SizedBox(width: 10),
                  Expanded(child: option('manual', 'Manual')),
                ],
              );
            },
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 14),
              child: Text(
                hint,
                style: TextStyle(fontSize: 12, color: t.muted, height: 1.4),
              ),
            ),
          if (failure?.field(key) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                failure!.field(key)!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
    }

    if (key.startsWith('notif_')) {
      final active = fields[key]!.text == '1';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: t.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          hint,
                          style: TextStyle(
                            fontSize: 12,
                            color: t.secondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Switch(
                  key: Key('setting-$key'),
                  value: active,
                  activeThumbColor: t.surface,
                  activeTrackColor: t.green,
                  onChanged: busy || loading
                      ? null
                      : (v) => setState(() {
                          fields[key]!.text = v ? '1' : '0';
                        }),
                ),
              ],
            ),
          ),
          if (failure?.field(key) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                failure!.field(key)!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
    }

    return ManagementField(
      id: 'setting-$key',
      label: label,
      controller: fields[key]!,
      enabled: !busy && !loading,
      hint: hint,
      keyboard: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      error: failure?.field(key),
    );
  }

  Widget _pairRow(String sectionId, String leftKey, String rightKey) {
    final labels = _fields[sectionId]!;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 400 || scale > 1.35) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              input(leftKey, labels[leftKey]!),
              input(rightKey, labels[rightKey]!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: input(leftKey, labels[leftKey]!)),
            const SizedBox(width: 12),
            Expanded(child: input(rightKey, labels[rightKey]!)),
          ],
        );
      },
    );
  }

  List<Widget> _buildSectionFields(String sectionId) {
    if (sectionId == 'climate') {
      return [
        _pairRow(sectionId, 'th_suhu_min', 'th_suhu_max'),
        _pairRow(sectionId, 'th_hum_min', 'th_hum_max'),
      ];
    }
    if (sectionId == 'soil') {
      return [
        _pairRow(sectionId, 'soil_on', 'soil_off'),
        _pairRow(sectionId, 'tank_min', 'pump_max_run'),
        input('pump_mode', _fields['soil']!['pump_mode']!),
      ];
    }
    return [
      for (final entry in _fields[sectionId]!.entries)
        input(entry.key, entry.value),
    ];
  }

  Widget _mqttWebSummaryBox(BuildContext context) {
    final t = GrowviaTokens.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (scale > 1.35) ...[
            Row(
              children: [
                GrowviaIcon('lock', size: 15, color: t.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kredensial Broker MQTT (Panel Web)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const GrowviaBadge('Web Only', tone: 'neutral'),
          ] else
            Row(
              children: [
                GrowviaIcon('lock', size: 15, color: t.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kredensial Broker MQTT (Panel Web)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const GrowviaBadge('Web Only', tone: 'neutral'),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Host, port, username, dan topik dasar broker diatur dari Laravel Web (/pengaturan#mqtt). Mobile tetap dapat mengubah interval pembaruan di bawah.',
            style: TextStyle(fontSize: 12.5, color: t.secondary, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionPanel(BuildContext context, String sectionId) {
    final meta = _sectionMeta[sectionId]!;
    final t = GrowviaTokens.of(context);
    return Panel(
      key: _sectionKeys[sectionId],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GrowviaIconTile(icon: meta.icon, tone: meta.tone, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          meta.eyebrow.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                            color: t.muted,
                          ),
                        ),
                        GrowviaBadge(meta.badge, tone: meta.tone),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.secondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: t.line),
          const SizedBox(height: 18),
          if (sectionId == 'general') _mqttWebSummaryBox(context),
          ..._buildSectionFields(sectionId),
          if (sectionId == 'soil')
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.soft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.line),
                ),
                child: Text(
                  'Mode manual di sini hanya nilai konfigurasi tersimpan, bukan tombol kontrol pompa.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: t.secondary,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                key: Key('settings-save-$sectionId'),
                onPressed: busy || loading ? null : () => saveSection(sectionId),
                child: Text(meta.saveLabel),
              ),
              OutlinedButton(
                key: Key('settings-revert-$sectionId'),
                onPressed: busy || loading
                    ? null
                    : () => setState(() {
                        for (final key in _fields[sectionId]!.keys) {
                          fields[key]!.text = saved![key]!;
                        }
                        failure = null;
                        receipt = null;
                      }),
                child: const Text('Batalkan perubahan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBodyChildren(BuildContext context) => [
    if (!widget.embedded) ...[
      const PageIntro(
        eyebrow: 'Kelola / Pengaturan',
        title: 'Konfigurasi tersimpan',
        description:
            'Semua pengaturan sistem kebun tampil langsung selaras dengan Laravel /pengaturan. Menyimpan konfigurasi tidak langsung menyalakan pompa.',
      ),
      const Notice(
        title: 'Broker MQTT hanya diatur dari web',
        message:
            'API mobile sengaja tidak mengirim kredensial broker. Atur host, port, pengguna, dan topik di halaman Pengaturan web.',
      ),
    ],
    ...feedback,
    if (loading)
      const LinearProgressIndicator(semanticsLabel: 'Memuat pengaturan'),
    if (loadFailure != null)
      ManagementError(failure: loadFailure!, retry: load),
    if (saved != null)
      for (var i = 0; i < _sectionOrder.length; i++) ...[
        if (widget.embedded && (i > 0 || feedback.isNotEmpty || loading))
          const SizedBox(height: 14),
        _buildSectionPanel(context, _sectionOrder[i]),
      ],
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      if (!authorized) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildBodyChildren(context),
      );
    }
    return protectedPage('Pengaturan sistem', () => _buildBodyChildren(context));
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }
}
