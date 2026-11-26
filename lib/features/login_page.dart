import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';
import '../core/preferences.dart';
import '../core/tokens.dart';
import '../data/api_client.dart';
import '../ui/components.dart';
import '../ui/growvia_components.dart';
import '../ui/growvia_icon.dart';
import 'recovery_page.dart';
import 'settings_page.dart';

/// Ukuran ikon di dalam field login, mengikuti token `.icon` web (20px).
const double _fieldIconSize = 20;

/// Target sentuh minimum 48x48 untuk ikon awal dan tombol akhir field.
const BoxConstraints _fieldIconConstraints = BoxConstraints(
  minWidth: 48,
  minHeight: 48,
);

/// Ikon awal field: target sentuh 48x48, glyph tetap 20px.
///
/// `InputDecorator` membungkus `prefixIcon` dengan constraint minimum 48px.
/// Tanpa [Center], [GrowviaIcon] ikut melar ke 48px dan painter-nya
/// menskalakan viewBox 24 menjadi 48, ikon tampil dua kali lebih besar
/// daripada ikon tombol mata di field yang sama.
class _FieldPrefixIcon extends StatelessWidget {
  const _FieldPrefixIcon(this.icon);

  final GrowviaIcon icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _fieldIconConstraints.minWidth,
    height: _fieldIconConstraints.minHeight,
    child: Center(child: icon),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _visible = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.login(_email.text.trim(), _password.text);
      TextInput.finishAutofillContext();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Sesi belum dapat disimpan dengan aman. Silakan coba kembali.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = widget.controller.preferences;
    final configured = preferences.apiUrl.isNotEmpty;
    final t = GrowviaTokens.of(context);
    return Scaffold(
      backgroundColor: t.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final form = _formPanel(context, preferences, configured);
          if (!wide) {
            return ColoredBox(
              color: t.canvas,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: t.storySurface,
                                    border: Border.all(color: t.line),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Brand(),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 84,
                                        height: 56,
                                        child: const GrowviaGardenArt(
                                          height: 56,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: t.surface,
                                    border: Border.all(color: t.line),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: t.scrim.withValues(alpha: 0.04),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: form,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                      child: _footer(context),
                    ),
                  ],
                ),
              ),
            );
          }
          return Row(
            children: [
              Expanded(child: _story(context)),
              Expanded(
                child: ColoredBox(
                  color: t.surface,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(48, 28, 48, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _accessBadge(context),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 28,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 400,
                                ),
                                child: form,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(48, 8, 48, 20),
                          child: _footer(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Panel cerita kiri, padanan `.auth-story` di layout web.
  Widget _story(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return ColoredBox(
      color: t.storySurface,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(48, 36, 48, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Brand(),
              const SizedBox(height: 56),
              Text(
                'PERHATIAN KECIL. TUMBUH LEBIH BAIK.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: t.secondary,
                ),
              ),
              const SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Ruang tumbuh.\nRuang untuk\n'),
                    TextSpan(
                      text: 'lebih peduli.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: t.green,
                      ),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontFamily: 'Horizon',
                  fontSize: 54,
                  height: 1.02,
                  letterSpacing: -1.7,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  'Kenalan sama kondisi rumah kaca dan kelola kebun dari satu ruang kerja yang simpel.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: t.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: const GrowviaGardenArt(height: 220),
              ),
              const SizedBox(height: 32),
              Builder(
                builder: (context) {
                  final label = TextStyle(fontSize: 12, color: t.secondary);
                  final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
                  if (scale > 1.4) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ruang kerja rumah kaca', style: label),
                        const SizedBox(height: 4),
                        Text('Dirawat bareng.', style: label),
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ruang kerja rumah kaca', style: label),
                      Text('Dirawat bareng.', style: label),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accessBadge(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GrowviaIcon('shield', size: 15, color: t.green),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'Akses ruang kerja terjaga',
            style: TextStyle(fontSize: 12, color: t.secondary),
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) => Text(
    'Growvia / Perhatian kecil, tumbuh lebih baik.',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _formPanel(
    BuildContext context,
    AppPreferences preferences,
    bool configured,
  ) {
    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageIntro(
              eyebrow: 'Akses akun',
              title: 'Masuk ke Growvia',
              description:
                  'Pantau rumah kaca dan rawat kebun dengan lebih tenang.',
            ),
            const SizedBox(height: 28),
            TextFormField(
              key: const Key('login-email'),
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: _FieldPrefixIcon(
                  GrowviaIcon('mail', size: _fieldIconSize),
                ),
                prefixIconConstraints: _fieldIconConstraints,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              validator: (value) =>
                  value == null ||
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value.trim())
                  ? 'Masukkan email yang valid.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('login-password'),
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Kata sandi',
                prefixIcon: const _FieldPrefixIcon(
                  GrowviaIcon('lock', size: _fieldIconSize),
                ),
                prefixIconConstraints: _fieldIconConstraints,
                suffixIconConstraints: _fieldIconConstraints,
                suffixIcon: IconButton(
                  tooltip: _visible
                      ? 'Sembunyikan kata sandi'
                      : 'Tampilkan kata sandi',
                  onPressed: () => setState(() => _visible = !_visible),
                  icon: GrowviaIcon(_visible ? 'eye' : 'eye-off'),
                ),
              ),
              obscureText: !_visible,
              autofillHints: const [AutofillHints.password],
              enableSuggestions: false,
              autocorrect: false,
              onFieldSubmitted: configured ? (_) => _login() : null,
              validator: (value) => value == null || value.isEmpty
                  ? 'Masukkan kata sandi.'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RecoveryPage(controller: widget.controller),
                        ),
                      ),
                child: const Text('Lupa kata sandi?'),
              ),
            ),
            FilledButton(
              onPressed: configured && !_busy ? _login : null,
              child: Text(_busy ? 'Memeriksa akun…' : 'Masuk'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Notice(title: 'Belum bisa masuk', message: _error!, error: true),
            ],
            if (widget.controller.message != null) ...[
              const SizedBox(height: 16),
              Notice(
                title: 'Informasi sesi',
                message: widget.controller.message!,
              ),
            ],
            // Kartu status API hanya muncul saat backend belum terhubung;
            // info "Tujuan API sudah diatur" dianggap mengganggu dan dihapus.
            if (!configured) ...[
              const SizedBox(height: 24),
              const Notice(
                title: 'Backend belum terhubung',
                message:
                    'Atur alamat API mobile lokal atau HTTPS, lalu masuk dengan akun Growvia yang sama seperti website.',
              ),
            ],
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Koneksi aplikasi')),
                          body: SafeArea(
                            top: false,
                            child: SettingsPage(
                              preferences: widget.controller.preferences,
                              updater: widget.controller.updater,
                            ),
                          ),
                        ),
                      ),
                    ),
              icon: const GrowviaIcon('settings', size: 20),
              label: const Text('Atur koneksi API'),
            ),
          ],
        ),
      ),
    );
  }
}
