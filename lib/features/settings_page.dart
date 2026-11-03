import 'package:flutter/material.dart';

import '../core/preferences.dart';
import '../ui/components.dart';
import '../ui/management_components.dart';

/// Pengaturan perangkat (alamat API, tema).
///
/// [embedded] dipakai bila halaman ini disisipkan ke halaman lain yang sudah
/// memiliki area gulir sendiri (mis. tab Preferensi di ruang kerja). Tanpa
/// flag itu, halaman ini membungkus isinya dengan [PageBody] seperti biasa.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.preferences,
    this.embedded = false,
    super.key,
  });

  final AppPreferences preferences;
  final bool embedded;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _url;
  late ThemeMode _theme;
  bool _busy = false;
  String? _receipt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.preferences.apiUrl);
    _theme = widget.preferences.themeMode;
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _receipt = null;
      _error = null;
    });
    try {
      await widget.preferences.save(_url.text, _theme);
      if (!mounted) return;
      setState(
        () => _receipt = 'Tersimpan di perangkat ini. Tidak ada permintaan ke server. Koneksi belum diverifikasi; verifikasi akun dilakukan saat masuk.',
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Pengaturan belum tersimpan. Coba kembali.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = widget.preferences;
    final content = <Widget>[
      const PageIntro(
        eyebrow: 'Preferensi lokal',
        title: 'Pengaturan perangkat ini',
        description:
            'Konfigurasi aplikasi terpisah dari pengaturan perangkat rumah kaca.',
      ),
      const SizedBox(height: 24),
      if (preferences.storageError != null) ...[
        Notice(
          title: 'Preferensi lokal',
          message: preferences.storageError!,
          error: true,
        ),
        const SizedBox(height: 16),
      ],
      Form(
        key: _form,
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Koneksi REST API',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Isi alamat API milikmu, bukan URL halaman login website. Tidak ada permintaan yang dikirim saat menyimpan.',
              ),
              if (preferences.endpointPolicy.localHttpAllowed) ...[
                const SizedBox(height: 12),
                const Notice(
                  title: 'HTTP lokal · khusus debug',
                  message:
                      'HTTP tidak terenkripsi. USB dengan adb reverse tcp:8000 tcp:8000: gunakan http://127.0.0.1:8000/api/v1 atau http://localhost:8000/api/v1. Android Emulator: gunakan http://10.0.2.2:8000/api/v1. Hanya tiga host lokal ini yang diizinkan; build release/profile wajib HTTPS.',
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('api-url'),
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Alamat API',
                  hintText: 'https://domain-kamu/api/v1',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                validator: (value) => preferences.endpointPolicy.validate(
                  value ?? '',
                  allowEmpty: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'API mobile lokal menggunakan Laravel Sanctum dan akun Growvia yang sama seperti website setelah server dijalankan. Koneksi belum diverifikasi sampai akun berhasil masuk. Perubahan alamat berlaku untuk login berikutnya, bukan sesi yang sedang aktif.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Tema tampilan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ManagementSelector(
                id: 'theme-choice',
                label: 'Pilihan tema',
                value: _theme.name,
                options: const {
                  'system': 'Ikuti sistem',
                  'light': 'Terang',
                  'dark': 'Gelap',
                },
                enabled: !_busy,
                onChanged: (value) => setState(() {
                  _theme = ThemeMode.values.firstWhere(
                    (mode) => mode.name == value,
                    orElse: () => ThemeMode.system,
                  );
                }),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Menyimpan…' : 'Simpan di perangkat'),
              ),
              if (_receipt != null) ...[
                const SizedBox(height: 16),
                Notice(title: 'Pengaturan disimpan', message: _receipt!),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Notice(title: 'Belum tersimpan', message: _error!, error: true),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Notice(
        title: 'MQTT belum diaktifkan',
        message:
            'Koneksi sensor dan kontrol pompa belum dikerjakan. Tidak ada kredensial broker yang disimpan di aplikasi.',
      ),
      const SizedBox(height: 20),
      const Text('Growvia Mobile · 0.1.0\nBahasa Indonesia · Android & iOS'),
    ];

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: content,
      );
    }
    return PageBody(children: content);
  }
}
