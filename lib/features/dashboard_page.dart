import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/tokens.dart';
import '../ui/charts.dart';
import '../ui/components.dart';
import '../ui/dashboard_components.dart';
import '../ui/growvia_components.dart';
import '../ui/growvia_icon.dart';
import 'account_page.dart';
import 'activity_page.dart';
import 'guide_page.dart';
import 'node_detail_page.dart';
import 'system_settings_page.dart';
import 'users_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.controller, super.key});
  final AppController controller;

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _refresh() async {
    await Future.wait([
      controller.refresh(),
      loadWorkspaceForDisplay(controller),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = GrowviaTokens.of(context);
    return RefreshIndicator(
      onRefresh: c.preview ? () async {} : _refresh,
      child: PageBody(
        children: [
          PageIntro(
            eyebrow: c.isAdmin ? 'Ruang kerja / Ringkasan' : 'Kebun saya',
            title: c.isAdmin
                ? 'Gambaran kebun hari ini.'
                : 'Kebun dalam genggaman.',
            description: c.isAdmin
                ? 'Pantau lingkungan tumbuh, perangkat, dan rencana perawatan kebun.'
                : 'Gambaran kebun hari ini. Perhatikan lingkungan tumbuh, akar, dan airnya.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GrowviaBadge(
                c.preview
                    ? 'Tanpa akun'
                    : c.isAdmin
                    ? 'Administrator'
                    : 'Petani',
                tone: 'green',
                dot: true,
              ),
              const GrowviaBadge('Menunggu data'),
            ],
          ),
          const SizedBox(height: 20),
          if (c.preview)
            const Notice(
              title: 'Mode pratinjau',
              message: 'Bukan sesi masuk. Jelajahi tampilan kebun dan panduan tanpa akun. Data sensor dan pengelolaan server tidak tersedia dalam pratinjau.',
            )
          else ...[
            GrowviaConnectionNotice(
              onTap: c.isAdmin
                  ? () => _open(context, SystemSettingsPage(controller: c))
                  : null,
            ),
            const SizedBox(height: 12),
            Notice(
              title: 'Halo, ${c.session!.name}',
              message: 'Akun diverifikasi melalui REST API. Telemetri sensor belum diaktifkan; MQTT dan kontrol pompa belum aktif. Ini bukan status realtime.',
            ),
          ],
          const SizedBox(height: 20),
          ResponsiveTiles(
            minimumWidth: 155,
            children: [
              MetricCard(
                label: 'Suhu udara',
                unit: '°C',
                icon: 'thermometer',
                tone: 'amber',
                reading: c.readings
                    .where(
                      (r) =>
                          r.metric == 'temperature' &&
                          r.node == 'node1' &&
                          r.unit == '°C',
                    )
                    .firstOrNull,
              ),
              MetricCard(
                label: 'Kelembapan tanah',
                unit: '%',
                icon: 'leaf',
                reading: c.readings
                    .where(
                      (r) =>
                          r.metric == 'soil_moisture' &&
                          r.node == 'node2' &&
                          r.unit == '%',
                    )
                    .firstOrNull,
              ),
              MetricCard(
                label: 'Isi tandon',
                unit: '%',
                icon: 'tank',
                tone: 'blue',
                reading: c.readings
                    .where(
                      (r) =>
                          r.metric == 'water_level' &&
                          r.node == 'node2' &&
                          r.unit == '%',
                    )
                    .firstOrNull,
              ),
              const MetricCard(
                label: 'Status pompa',
                icon: 'power',
                tone: 'neutral',
                note: 'Status perangkat belum tersedia',
              ),
            ],
          ),
          if (c.loadingWorkspace)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
          if (c.workspaceError != null) ...[
            const SizedBox(height: 16),
            Notice(
              title: 'Ringkasan server belum dimuat',
              message: c.workspaceError!,
              error: true,
            ),
          ],
          if (c.dataError != null) ...[
            const SizedBox(height: 16),
            Notice(
              title: 'Data belum dapat dimuat',
              message: c.dataError!,
              error: true,
            ),
          ],
          if (!c.preview)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: c.loadingReadings || c.loadingWorkspace
                      ? null
                      : _refresh,
                  icon: const GrowviaIcon('refresh', size: 16),
                  label: Text(
                    c.loadingReadings || c.loadingWorkspace
                        ? 'Memuat data…'
                        : 'Perbarui data tersimpan',
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Grafik kosong, sama seperti `<x-empty-chart>` di web.
          GrowviaEmptyChart(
            title: 'Tren suhu udara',
            subtitle: 'Riwayat pembacaan sensor',
            node: 'Node1',
            period: '24 jam',
            cta: c.preview
                ? null
                : GrowviaTextLink(
                    label: 'Perbarui data',
                    icon: 'refresh',
                    onTap: c.loadingReadings || c.loadingWorkspace
                        ? null
                        : _refresh,
                  ),
          ),
          const SizedBox(height: 20),
          const GrowviaNodeStatus(),
          const SizedBox(height: 20),
          GrowviaPanel(
            title: 'Kontrol pompa',
            subtitle: 'Irigasi / Node2',
            headerTrailing: const GrowviaBadge('Belum aktif'),
            child: Column(
              children: [
                const GrowviaPumpVisual(),
                const SizedBox(height: 18),
                Text(
                  'Menunggu integrasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const GrowviaIcon('power', size: 16),
                    label: const Text('Nyalakan manual'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kontrol perangkat belum tersedia. Menyimpan konfigurasi tidak menyalakan pompa.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: t.secondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          // Padanan `.guide-callout` di `petani/dashboard.blade.php`.
          Panel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GrowviaIcon('book', size: 22, color: t.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Masih bingung baca angka sensor?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mulai dari panduan singkat soal suhu, tanah, dan cara menyiram.',
                        style: TextStyle(fontSize: 12, color: t.secondary),
                      ),
                      const SizedBox(height: 8),
                      GrowviaTextLink(
                        label: 'Pelajari',
                        onTap: () => _open(
                          context,
                          Scaffold(
                            appBar: AppBar(title: const Text('Edukasi')),
                            body: const SafeArea(
                              top: false,
                              child: GuidePage(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          GrowviaSectionHeading(
            eyebrow: 'Node1 / Lingkungan tumbuh',
            title: 'Iklim rumah kaca',
            trailing: const GrowviaBadge('Menunggu data'),
          ),
          GrowviaNodeOverview(
            key: const Key('open-climate'),
            node: 'node1',
            title: 'Node1 · Iklim',
            subtitle: 'Suhu, kelembapan udara, cahaya, dan CO2',
            icon: 'sun',
            tone: 'amber',
            onTap: () =>
                _open(context, NodeDetailPage(controller: c, node: 'node1')),
          ),
          const SizedBox(height: 12),
          GrowviaNodeOverview(
            key: const Key('open-soil'),
            node: 'node2',
            title: 'Node2 · Tanah & air',
            subtitle: 'Kelembapan tanah, tandon, dan rencana irigasi',
            icon: 'drop',
            tone: 'blue',
            onTap: () =>
                _open(context, NodeDetailPage(controller: c, node: 'node2')),
          ),
          if (c.session != null) ...[
            const SizedBox(height: 24),
            GrowviaSectionHeading(
              eyebrow: c.isAdmin ? 'Pengelolaan' : 'Akun & keamanan',
              title: c.isAdmin
                  ? 'Kelola kebun dan pengguna'
                  : 'Profil dan sesi perangkat',
            ),
            if (c.isAdmin) ...[
              if (c.workspace?.counts case final counts?) ...[
                Panel(
                  child: ResponsiveTiles(
                    minimumWidth: 180,
                    children: [
                      _Count(
                        label: 'Seluruh pengguna',
                        value: counts['users_total']?.toString() ?? '—',
                      ),
                      _Count(
                        label: 'Akun aktif',
                        value: counts['users_active']?.toString() ?? '—',
                      ),
                      _Count(
                        label: 'Akun nonaktif',
                        value: counts['users_inactive']?.toString() ?? '—',
                      ),
                      _Count(
                        label: 'Administrator',
                        value: counts['admins']?.toString() ?? '—',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GrowviaLinkTile(
                key: const Key('open-users'),
                title: 'Kelola pengguna',
                subtitle: 'Cari, tambah, edit, dan atur status akun',
                icon: 'users',
                onTap: () => _open(context, UsersPage(controller: c)),
              ),
              const SizedBox(height: 12),
              GrowviaLinkTile(
                key: const Key('open-activities'),
                title: 'Log aktivitas',
                subtitle: 'Riwayat akun, sesi, dan pengaturan',
                icon: 'clock',
                onTap: () => _open(context, ActivityPage(controller: c)),
              ),
              const SizedBox(height: 12),
              GrowviaLinkTile(
                key: const Key('open-system'),
                title: 'Pengaturan sistem',
                subtitle: 'Target lingkungan dan preferensi tersimpan',
                icon: 'settings',
                onTap: () => _open(context, SystemSettingsPage(controller: c)),
              ),
              const SizedBox(height: 12),
            ],
            GrowviaLinkTile(
              key: const Key('open-account'),
              title: 'Profil & keamanan',
              subtitle: 'Profil, kata sandi, dan sesi perangkat',
              icon: 'shield',
              onTap: () => _open(context, AccountPage(controller: c)),
            ),
          ],
          const SizedBox(height: 24),
          const GrowviaSectionHeading(
            eyebrow: 'Kondisi akar',
            title: 'Pembacaan tersimpan, bukan status realtime',
          ),
          Panel(
            child: Center(
              child: MoistureGauge(
                reading: c.readings
                    .where((r) => r.metric == 'soil_moisture' && r.unit == '%')
                    .firstOrNull,
              ),
            ),
          ),
          if (c.isAdmin) ...[
            const SizedBox(height: 24),
            GrowviaSectionHeading(
              eyebrow: 'Catatan aplikasi',
              title: 'Aktivitas terbaru',
              trailing: GrowviaTextLink(
                label: 'Lihat semua',
                onTap: () => _open(context, ActivityPage(controller: c)),
              ),
            ),
            if (c.workspace == null)
              const Text('Ringkasan aktivitas belum dimuat dari server.')
            else if (c.workspace!.recentActivities.isEmpty)
              const Panel(
                child: Text(
                  'Belum ada aktivitas aplikasi yang tercatat. Ini bukan riwayat perangkat.',
                ),
              )
            else
              Panel(
                child: Column(
                  children: [
                    for (final activity in c.workspace!.recentActivities)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GrowviaIcon('clock', size: 20, color: t.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(activity.actorName),
                                  Text(
                                    '${activity.createdAt.toUtc().toIso8601String()} UTC',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: t.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          Text(
            'Konfigurasi tersimpan bukan konfirmasi kondisi perangkat. Kontrol pompa tetap belum aktif.',
            style: TextStyle(color: t.secondary),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineMedium),
      Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}
