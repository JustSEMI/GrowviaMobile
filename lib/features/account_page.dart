import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';
import '../ui/components.dart';
import '../ui/growvia_icon.dart';
import '../ui/management_components.dart';
import 'sessions_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ProtectedManagementState<AccountPage> {
  @override
  AppController get controller => widget.controller;
  final name = TextEditingController(),
      email = TextEditingController(),
      verification = TextEditingController(),
      currentPassword = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();

  /// Form yang terakhir dikirim.
  ///
  /// Dua form memakai nama field server `current_password`, jadi error tidak
  /// boleh ditampilkan di kedua kolom sekaligus.
  String? _form;
  @override
  void initializeProtected() {
    setState(() {
      name.text = controller.session!.name;
      email.text = controller.session!.email;
    });
  }

  @override
  void clearPrivateData() {
    for (final field in [
      name,
      email,
      verification,
      currentPassword,
      password,
      confirmation,
    ]) {
      field.clear();
    }
  }

  void clearSecrets() {
    verification.clear();
    currentPassword.clear();
    password.clear();
    confirmation.clear();
    TextInput.finishAutofillContext(shouldSave: false);
  }

  Future<void> profile() async {
    _form = 'profile';
    final errors = requiredFields({'name': name.text, 'email': email.text});
    final sensitive = email.text.trim() != controller.session?.email;
    if (!validEmail(email.text.trim())) {
      errors['email'] = ['Masukkan alamat email yang valid.'];
    }
    if (sensitive && verification.text.isEmpty) {
      errors['current_password'] = [
        'Kata sandi saat ini diperlukan untuk mengganti email.',
      ];
    }
    if (errors.isNotEmpty) {
      setState(() {
        receipt = null;
        failure = ManagementFailure('Profil belum disimpan.', errors);
      });
      return;
    }
    if (await write(
      () => controller.updateProfile(
        name: name.text.trim(),
        email: email.text.trim(),
        currentPassword: sensitive ? verification.text : null,
      ),
      sensitive
          ? 'Profil disimpan. Sesi lain dicabut dan sesi perangkat ini diperbarui dengan aman.'
          : 'Profil berhasil disimpan.',
    )) {
      clearSecrets();
      setState(() {
        name.text = controller.session!.name;
        email.text = controller.session!.email;
      });
    }
  }

  Future<void> change() async {
    _form = 'password';
    final errors = requiredFields({
      'current_password': currentPassword.text,
      'password': password.text,
      'password_confirmation': confirmation.text,
    });
    if (password.text.length < 8) {
      errors['password'] = ['Gunakan setidaknya 8 karakter.'];
    }
    if (password.text != confirmation.text) {
      errors['password_confirmation'] = ['Konfirmasi kata sandi harus sama.'];
    }
    if (errors.isNotEmpty) {
      setState(() {
        receipt = null;
        failure = ManagementFailure('Kata sandi belum diubah.', errors);
      });
      return;
    }
    if (await write(
      () => controller.changePassword(
        currentPassword: currentPassword.text,
        password: password.text,
        confirmation: confirmation.text,
      ),
      'Kata sandi berhasil diubah. Sesi lain dicabut dan sesi perangkat ini diperbarui dengan aman.',
    )) {
      clearSecrets();
    }
  }

  @override
  Widget build(BuildContext context) => protectedPage(
    'Akun saya',
    () => [
      const PageIntro(
        eyebrow: 'Keamanan akun',
        title: 'Profil & kata sandi',
        description: 'Perubahan email dan kata sandi memerlukan verifikasi kata sandi saat ini. Sesi lain akan dicabut.',
      ),
      ...feedback,
      Panel(
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              managementHeading(context, 'Profil'),
              ManagementField(
                id: 'account-name',
                label: 'Nama',
                controller: name,
                enabled: !busy,
                error: failure?.field('name'),
                autofill: const [AutofillHints.name],
              ),
              ManagementField(
                id: 'account-email',
                label: 'Email',
                controller: email,
                enabled: !busy,
                keyboard: TextInputType.emailAddress,
                error: failure?.field('email'),
                autofill: const [AutofillHints.email],
              ),
              ManagementField(
                id: 'account-verification',
                label: 'Kata sandi saat ini',
                controller: verification,
                enabled: !busy,
                secret: true,
                error: _form == 'profile'
                    ? failure?.field('current_password')
                    : null,
                hint: 'Wajib hanya jika alamat email diubah.',
                autofill: const [AutofillHints.password],
              ),
              FilledButton(
                key: const Key('account-save'),
                onPressed: busy ? null : profile,
                child: const Text('Simpan profil'),
              ),
            ],
          ),
        ),
      ),
      Panel(
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              managementHeading(context, 'Ganti kata sandi'),
              ManagementField(
                id: 'account-current-password',
                label: 'Kata sandi saat ini',
                controller: currentPassword,
                enabled: !busy,
                secret: true,
                error: _form == 'password'
                    ? failure?.field('current_password')
                    : null,
                autofill: const [AutofillHints.password],
              ),
              ManagementField(
                id: 'account-new-password',
                label: 'Kata sandi baru',
                controller: password,
                enabled: !busy,
                secret: true,
                error: failure?.field('password'),
                hint: 'Minimal 8 karakter.',
                autofill: const [AutofillHints.newPassword],
              ),
              ManagementField(
                id: 'account-confirmation',
                label: 'Konfirmasi kata sandi baru',
                controller: confirmation,
                enabled: !busy,
                secret: true,
                error: failure?.field('password_confirmation'),
                autofill: const [AutofillHints.newPassword],
              ),
              FilledButton(
                key: const Key('account-change-password'),
                onPressed: busy ? null : change,
                child: const Text('Ubah kata sandi'),
              ),
            ],
          ),
        ),
      ),
      OutlinedButton.icon(
        key: const Key('account-sessions'),
        onPressed: busy
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SessionsPage(controller: controller),
                ),
              ),
        icon: const GrowviaIcon('display'),
        label: const Text('Perangkat & sesi'),
      ),
    ],
  );
  @override
  void dispose() {
    for (final field in [
      name,
      email,
      verification,
      currentPassword,
      password,
      confirmation,
    ]) {
      field.dispose();
    }
    super.dispose();
  }
}
