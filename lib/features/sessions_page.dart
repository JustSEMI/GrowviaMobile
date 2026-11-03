import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';
import '../data/workspace_models.dart';
import '../ui/components.dart';
import '../ui/growvia_icon.dart';
import '../ui/management_components.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ProtectedManagementState<SessionsPage> {
  @override
  AppController get controller => widget.controller;
  final password = TextEditingController();
  ApiPage<DeviceSession>? result;
  ManagementFailure? loadFailure;
  bool loading = false;
  int readGeneration = 0;
  @override
  void initializeProtected() {
    load();
  }

  @override
  void clearPrivateData() {
    readGeneration++;
    result = null;
    loadFailure = null;
    password.clear();
  }

  Future<void> load([int page = 1]) async {
    if (!authorized) return;
    final ticket = generation, read = ++readGeneration;
    setState(() {
      loading = true;
      // Daftar lama tetap tampil selama halaman berikutnya dimuat; jangan
      // kosongkan dulu supaya layar tidak berkedip.
      loadFailure = null;
    });
    try {
      final next = await controller.loadSessions(page: page);
      if (current(ticket) && read == readGeneration) {
        setState(() {
          result = next;
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

  Future<void> revoke() async {
    if (password.text.isEmpty) {
      setState(() {
        receipt = null;
        failure = const ManagementFailure('Verifikasi diperlukan.', {
          'current_password': ['Masukkan kata sandi saat ini.'],
        });
      });
      return;
    }
    final confirmed = await confirmManagement(
      context,
      title: 'Keluar dari sesi lain?',
      message: 'Semua sesi web dan mobile lain akan dicabut. Perangkat ini tetap masuk setelah token baru disimpan dengan aman.',
      confirm: 'Keluar sesi lain',
    );
    if (!mounted || !authorized || !confirmed) return;
    if (await write(
      () => controller.revokeOtherSessions(password.text),
      'Sesi lain berhasil dicabut. Perangkat ini tetap masuk.',
    )) {
      password.clear();
      TextInput.finishAutofillContext(shouldSave: false);
      await load();
    }
  }

  Widget deviceCard(DeviceSession device) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GrowviaIcon(
            device.kind == 'web' ? 'connection' : 'display',
          ),
        ),
        const SizedBox(height: 8),
        Text(device.label, style: Theme.of(context).textTheme.titleMedium),
        if (device.current)
          Text(
            'Perangkat ini',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        Text(device.device),
        Text('Jenis: ${device.kind == 'web' ? 'Web' : 'Mobile'}'),
        Text('IP: ${device.ip ?? 'Tidak tersedia'}'),
        Text('Aktif terakhir: ${utcLabel(device.lastActive)}'),
        Text('Kedaluwarsa: ${utcLabel(device.expiresAt)}'),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => protectedPage(
    'Perangkat & sesi',
    () => [
      const PageIntro(
        eyebrow: 'Akun saya',
        title: 'Sesi masuk',
        description: 'Hanya sesi akun Anda. Semua waktu ditampilkan dalam UTC; tidak ada ID atau token sesi yang ditampilkan.',
      ),
      ...feedback,
      Panel(
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              managementHeading(context, 'Amankan akun'),
              ManagementField(
                id: 'sessions-password',
                label: 'Kata sandi saat ini',
                controller: password,
                secret: true,
                enabled: !busy,
                error: failure?.field('current_password'),
                autofill: const [AutofillHints.password],
              ),
              FilledButton(
                key: const Key('sessions-revoke'),
                onPressed: busy ? null : revoke,
                child: const Text('Keluar dari sesi lain'),
              ),
            ],
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: loading || busy ? null : () => load(),
        icon: const GrowviaIcon('refresh'),
        label: const Text('Muat ulang sesi'),
      ),
      if (loading) const LinearProgressIndicator(semanticsLabel: 'Memuat sesi'),
      if (loadFailure != null)
        ManagementError(failure: loadFailure!, retry: () => load()),
      if (result != null) ...[
        if (!result!.webSupported)
          const Notice(
            title: 'Daftar sesi web tidak tersedia',
            message: 'Penyimpanan sesi web server tidak mendukung daftar perangkat. Ini tidak berarti tidak ada sesi web.',
          ),
        if (result!.data.isEmpty)
          const Notice(
            title: 'Tidak ada sesi yang ditampilkan',
            message: 'Muat ulang untuk memeriksa daftar sesi akun Anda.',
          ),
        ManagementPagination(
          page: result!.currentPage,
          lastPage: result!.lastPage,
          total: result!.total,
          onPage: load,
          busy: loading || busy,
        ),
        ...result!.data.map(deviceCard),
      ],
    ],
  );
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }
}
