import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';
import '../data/api_endpoint.dart';
import '../ui/components.dart';
import '../ui/management_components.dart';

/// Hanya mem-parsing tautan reset dari Laravel. Tidak pernah melakukan request ke URL tersebut.
({String email, String token})? parseRecoveryLink(
  String input, {
  required String baseUrl,
  bool allowDebugAliases = true,
}) {
  final text = input.trim();
  if (text.isEmpty ||
      text.length > 4096 ||
      RegExp(r'[\x00-\x20\x7f]').hasMatch(text)) {
    return null;
  }
  try {
    // Validasi authority/path mentah sebelum Uri menormalisasi traversal atau
    // userinfo kosong. Rute recovery berinduk di web origin, bukan /api/v1.
    final raw = RegExp(
      r'^(https?://[^/?#]+)(/[^?#]*)(\?[^#]*)?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (raw == null ||
        !RegExp(r'^/(reset-sandi|reset-password)/[a-fA-F0-9]{64}$')
            .hasMatch(raw.group(2)!)) {
      return null;
    }
    final policy = ApiEndpoint(allowDebugHttp: allowDebugAliases);
    if (policy.validate(raw.group(1)!) != null) return null;
    final trusted = policy.parse(baseUrl);
    final uri = Uri.parse(text);
    final sameHost =
        uri.host == trusted.host ||
        (kDebugMode &&
            allowDebugAliases &&
            ApiEndpoint.localHosts.contains(uri.host) &&
            ApiEndpoint.localHosts.contains(trusted.host));
    if (uri.scheme != trusted.scheme || uri.port != trusted.port || !sameHost) {
      return null;
    }
    if (!['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return null;
    }
    final segments = uri.pathSegments;
    if (segments.length != 2 ||
        !['reset-sandi', 'reset-password'].contains(segments[0])) {
      return null;
    }
    if (uri.queryParametersAll.keys.any((key) => key != 'email')) return null;
    final token = segments[1];
    // Broker kata sandi Laravel menggunakan token heksadesimal SHA-256 (64 karakter).
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(token)) return null;
    final emails = uri.queryParametersAll['email'];
    if (emails == null || emails.length != 1 || !validEmail(emails.single)) {
      return null;
    }
    return (email: emails.single, token: token);
  } on FormatException {
    return null;
  }
}

class RecoveryPage extends StatefulWidget {
  const RecoveryPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  final requestEmail = TextEditingController(),
      link = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  String? token, receipt, boundBaseUrl;
  ManagementFailure? failure;
  bool busy = false;
  int generation = 0;
  final pageScroll = ScrollController();
  ManagementFailure? shownFailure;
  String? shownReceipt;
  AppController get controller => widget.controller;
  @override
  void initState() {
    super.initState();
    controller.addListener(changed);
    controller.preferences.addListener(changed);
    link.addListener(linkChanged);
  }

  void invalidateLink() {
    token = null;
    boundBaseUrl = null;
    email.clear();
  }

  void linkChanged() {
    if (!mounted) return;
    setState(() {
      invalidateLink();
      receipt = null;
    });
  }

  void changed() {
    if (!mounted) return;
    if (controller.preview ||
        controller.session != null ||
        (boundBaseUrl != null &&
            boundBaseUrl != controller.preferences.apiUrl)) {
      generation++;
      clearSecrets();
      failure = null;
      receipt = null;
      busy = false;
    }
    setState(() {});
  }

  void clearSecrets() {
    invalidateLink();
    link.clear();
    password.clear();
    confirmation.clear();
  }

  Future<void> perform(
    Future<void> Function() operation,
    String success, {
    bool reset = false,
  }) async {
    if (busy || controller.preview || controller.session != null) return;
    final ticket = generation;
    setState(() {
      busy = true;
      failure = null;
      receipt = null;
    });
    try {
      await operation();
      if (!mounted || ticket != generation) return;
      setState(() {
        receipt = success;
        if (reset) {
          clearSecrets();
          requestEmail.clear();
        }
      });
      if (reset) TextInput.finishAutofillContext(shouldSave: false);
    } catch (error) {
      if (mounted && ticket == generation) {
        setState(() {
          failure = ManagementFailure.from(error);
        });
      }
    } finally {
      if (mounted && ticket == generation) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> request() async {
    if (!validEmail(requestEmail.text.trim())) {
      setState(() {
        failure = const ManagementFailure('Periksa email.', {
          'email': ['Masukkan alamat email yang valid.'],
        });
        receipt = null;
      });
      return;
    }
    await perform(
      () => controller.requestPasswordReset(requestEmail.text.trim()),
      'Permintaan diproses. Jika alamat tersebut memenuhi syarat, petunjuk pemulihan akan tersedia melalui pengiriman email server. Status keberadaan akun tidak ditampilkan.',
    );
  }

  void parse() {
    final baseUrl = controller.preferences.apiUrl;
    final parsed = parseRecoveryLink(link.text, baseUrl: baseUrl);
    setState(() {
      receipt = null;
      invalidateLink();
      if (parsed == null) {
        failure = const ManagementFailure('Tautan tidak valid.', {
          'link': [
            'Gunakan tautan /reset-sandi/TOKEN?email=… dari origin API yang dikonfigurasi. Tautan tidak dibuka atau diunduh.',
          ],
        });
      } else {
        // Bersihkan rahasia yang dapat diedit sebelum menerima binding baru: listener
        // membatalkan kredensial lama, bukan kredensial yang baru di-parse.
        link.clear();
        token = parsed.token;
        email.text = parsed.email;
        boundBaseUrl = baseUrl;
        failure = null;
      }
    });
  }

  Future<void> reset() async {
    if (boundBaseUrl != controller.preferences.apiUrl) {
      invalidateLink();
    }
    final errors = requiredFields({
      'email': email.text,
      'password': password.text,
      'password_confirmation': confirmation.text,
    });
    if (token == null) {
      errors['token'] = ['Baca tautan pemulihan yang valid terlebih dahulu.'];
    }
    if (!validEmail(email.text)) {
      errors['email'] = ['Email tautan tidak valid.'];
    }
    if (password.text.length < 8) {
      errors['password'] = ['Gunakan setidaknya 8 karakter.'];
    }
    if (password.text != confirmation.text) {
      errors['password_confirmation'] = ['Konfirmasi kata sandi harus sama.'];
    }
    if (errors.isNotEmpty) {
      setState(() {
        failure = ManagementFailure('Kata sandi belum direset.', errors);
        receipt = null;
      });
      return;
    }
    await perform(
      () => controller.resetPassword(
        email: email.text,
        token: token!,
        expectedBaseUrl: boundBaseUrl!,
        password: password.text,
        confirmation: confirmation.text,
      ),
      'Kata sandi berhasil direset. Kembali ke halaman masuk untuk menggunakan kata sandi baru.',
      reset: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (failure != shownFailure || receipt != shownReceipt) {
      shownFailure = failure;
      shownReceipt = receipt;
      if (failure != null || receipt != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && pageScroll.hasClients) pageScroll.jumpTo(0);
        });
      }
    }
    return ManagementScaffold(
      controller: pageScroll,
      title: 'Pemulihan akun',
      children: [
        const PageIntro(
          eyebrow: 'Akses akun',
          title: 'Lupa kata sandi?',
          description: 'Minta petunjuk pemulihan atau tempel tautan reset dari email. Tidak membuat akun baru.',
        ),
        if (controller.preview)
          const Notice(
            title: 'Mode pratinjau',
            message: 'Pemulihan tidak mengirim permintaan selama pratinjau. Kembali ke halaman masuk terlebih dahulu.',
          )
        else if (controller.session != null)
          const Notice(
            title: 'Anda masih masuk',
            message: 'Gunakan halaman Akun saya untuk mengganti kata sandi, atau keluar sebelum melakukan pemulihan.',
          )
        else ...[
          const Notice(
            title: 'Catatan pengiriman lokal',
            message: 'Aplikasi tidak dapat memastikan email sudah terkirim. Pada server lokal, mailer log/array mungkin hanya menyimpan email di server dan tidak mengirimkannya ke kotak masuk. Hubungi administrator; konfigurasi mailer tidak diubah di sini.',
          ),
          if (failure != null) ManagementError(failure: failure!),
          if (receipt != null)
            Semantics(
              liveRegion: true,
              child: Notice(
                key: const Key('recovery-receipt'),
                title: 'Hasil permintaan',
                message: receipt!,
              ),
            ),
          if (busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Memproses pemulihan',
            ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                managementHeading(context, 'Minta tautan pemulihan'),
                ManagementField(
                  id: 'recovery-request-email',
                  label: 'Email akun',
                  controller: requestEmail,
                  keyboard: TextInputType.emailAddress,
                  enabled: !busy,
                  error: failure?.field('email'),
                  autofill: const [AutofillHints.email],
                ),
                FilledButton(
                  key: const Key('recovery-request'),
                  onPressed: busy ? null : request,
                  child: const Text('Minta petunjuk'),
                ),
              ],
            ),
          ),
          Panel(
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  managementHeading(context, 'Reset kata sandi'),
                  ManagementField(
                    id: 'recovery-link',
                    label: 'Tautan reset dari email',
                    controller: link,
                    secret: true,
                    enabled: !busy,
                    error: failure?.field('link') ?? failure?.field('token'),
                    hint: 'Tautan hanya dibaca di perangkat, tidak pernah dibuka. Token disembunyikan.',
                  ),
                  OutlinedButton(
                    key: const Key('recovery-parse'),
                    onPressed: busy ? null : parse,
                    child: const Text('Baca tautan'),
                  ),
                  const SizedBox(height: 16),
                  if (token != null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Tautan dibaca. Keabsahan dan masa berlaku diverifikasi server saat reset.',
                      ),
                    ),
                  ManagementField(
                    id: 'recovery-email',
                    label: 'Email dari tautan',
                    controller: email,
                    enabled: false,
                    error: failure?.field('email'),
                  ),
                  ManagementField(
                    id: 'recovery-password',
                    label: 'Kata sandi baru',
                    controller: password,
                    secret: true,
                    enabled: !busy,
                    hint: 'Minimal 8 karakter.',
                    error: failure?.field('password'),
                    autofill: const [AutofillHints.newPassword],
                  ),
                  ManagementField(
                    id: 'recovery-confirmation',
                    label: 'Konfirmasi kata sandi baru',
                    controller: confirmation,
                    secret: true,
                    enabled: !busy,
                    error: failure?.field('password_confirmation'),
                    autofill: const [AutofillHints.newPassword],
                  ),
                  FilledButton(
                    key: const Key('recovery-reset'),
                    onPressed: busy || token == null ? null : reset,
                    child: const Text('Reset kata sandi'),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).maybePop(),
            child: const Text('Kembali ke masuk'),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    generation++;
    pageScroll.dispose();
    controller.removeListener(changed);
    controller.preferences.removeListener(changed);
    link.removeListener(linkChanged);
    for (final field in [requestEmail, link, email, password, confirmation]) {
      field.dispose();
    }
    super.dispose();
  }
}
