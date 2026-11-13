import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../ui/components.dart';
import '../ui/management_components.dart';

// Label mengikuti bagian di `resources/views/settings.blade.php`.
const _sections = {
  'general': 'Umum',
  'climate': 'Ambang iklim',
  'soil': 'Tanah & pompa',
  'notifications': 'Preferensi notifikasi',
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
  const SystemSettingsPage({required this.controller, super.key});
  final AppController controller;
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
  Map<String, String>? saved;
  ManagementFailure? loadFailure;
  String section = 'general';
  bool loading = false;
  int readGeneration = 0;
  @override
  void initializeProtected() {
    load();
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

  Future<void> save() async {
    final errors = <String, List<String>>{};
    final values = <String, dynamic>{};
    for (final key in _fields[section]!.keys) {
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
    for (final pair in [
      ['th_suhu_min', 'th_suhu_max'],
      ['th_hum_min', 'th_hum_max'],
      ['soil_on', 'soil_off'],
    ]) {
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
    final target = section;
    if (await write(
      () => controller.saveSystemSettings(target, values),
      'Konfigurasi ${_sections[target]} disimpan di server. Ini bukan konfirmasi penerapan ke perangkat; tidak ada perintah perangkat dikirim.',
    )) {
      // Baca ulang konfigurasi tersimpan yang dinormalisasi server, bukan hasil rekaan.
      await load();
    }
  }

  Widget input(String key, String label) {
    if (key == 'pump_mode' || key.startsWith('notif_')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManagementSelector(
            id: 'setting-$key',
            label: label,
            value: fields[key]!.text,
            options: key == 'pump_mode'
                ? const {'auto': 'Otomatis', 'manual': 'Manual'}
                : const {'1': 'Aktif', '0': 'Nonaktif'},
            enabled: !busy && !loading,
            onChanged: (v) => setState(() {
              fields[key]!.text = v;
            }),
          ),
          if (failure?.field(key) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
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
      keyboard: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      error: failure?.field(key),
    );
  }

  @override
  Widget build(BuildContext context) => protectedPage(
    'Pengaturan sistem',
    () => [
      const PageIntro(
        eyebrow: 'Administrasi',
        title: 'Konfigurasi tersimpan',
        description: 'Pengaturan non-MQTT pada backend Growvia. Menyimpan konfigurasi tidak menyalakan pompa atau mengirim perintah ke perangkat.',
      ),
      const Notice(
        title: 'Broker MQTT hanya diatur dari web',
        message: 'API mobile sengaja tidak mengirim kredensial broker. Atur host, port, pengguna, dan topik di halaman Pengaturan web.',
      ),
      ...feedback,
      if (loading)
        const LinearProgressIndicator(semanticsLabel: 'Memuat pengaturan'),
      if (loadFailure != null)
        ManagementError(failure: loadFailure!, retry: load),
      if (saved != null) ...[
        ManagementSelector(
          id: 'settings-section',
          label: 'Kelompok',
          value: section,
          options: _sections,
          enabled: !busy && !loading,
          onChanged: (v) => setState(() {
            section = v;
            failure = null;
            receipt = null;
          }),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              managementHeading(context, _sections[section]!),
              ..._fields[section]!.entries.map(
                (entry) => input(entry.key, entry.value),
              ),
              if (section == 'soil')
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Mode manual di sini hanya nilai konfigurasi tersimpan, bukan tombol kontrol pompa.',
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    key: const Key('settings-save'),
                    onPressed: busy || loading ? null : save,
                    child: const Text('Simpan kelompok'),
                  ),
                  OutlinedButton(
                    key: const Key('settings-revert'),
                    onPressed: busy || loading
                        ? null
                        : () => setState(() {
                            for (final key in _fields[section]!.keys) {
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
        ),
      ],
    ],
  );
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }
}
