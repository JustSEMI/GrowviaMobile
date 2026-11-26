import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/tokens.dart';
import '../data/reading.dart';
import '../ui/charts.dart';
import '../ui/components.dart';
import '../ui/dashboard_components.dart';
import '../ui/growvia_components.dart';
import '../ui/growvia_icon.dart';
import 'account_page.dart';
import 'activity_page.dart';
import 'backup_page.dart';
import 'guide_page.dart';
import 'node_detail_page.dart';
import 'system_settings_page.dart';
import 'users_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _chartMetric = 'temperature';

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _refresh() async {
    await Future.wait([
      widget.controller.refresh(),
      loadWorkspaceForDisplay(widget.controller),
    ]);
  }

  /// Waktu pencatatan terbaru di seluruh pembacaan, format `dd/MM HH:mm UTC`.
  static String _latestStamp(List<Reading> readings) {
    final latest = readings
        .map((r) => r.recordedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(latest.day)}/${two(latest.month)} '
        '${two(latest.hour)}:${two(latest.minute)} UTC';
  }

  Reading? _latestMetric(
    AppController c,
    String node,
    String metric,
    String unit,
  ) {
    for (final r in c.readings) {
      if (r.node == node &&
          r.metric == metric &&
          (unit.isEmpty || r.unit == unit)) {
        return unit.isEmpty ? r.asStateReading() : r;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final t = GrowviaTokens.of(context);
    final hasTelemetry =
        c.readings.isNotEmpty || (c.workspace?.telemetryAvailable ?? false);
    final tempSeries = c.readings
        .where(
          (r) => r.metric == 'temperature' && r.node == 'node1' && r.unit == '°C',
        )
        .toList();
    final humSeries = c.readings
        .where(
          (r) => r.metric == 'humidity' && r.node == 'node1' && r.unit == '%',
        )
        .toList();
    final soilSeries = c.readings
        .where(
          (r) =>
              r.metric == 'soil_moisture' && r.node == 'node2' && r.unit == '%',
        )
        .toList();
    final tankSeries = c.readings
        .where(
          (r) =>
              r.metric == 'water_level' && r.node == 'node2' && r.unit == '%',
        )
        .toList();

    final (chartTitle, chartNode, chartSeries, chartColor) = switch (_chartMetric) {
      'humidity' => ('Kelembapan udara · Device 1', 'Device 1', humSeries, t.blue),
      'soil_moisture' => ('Kelembapan tanah · Device 2', 'Device 2', soilSeries, t.green),
      'water_level' => ('Isi tandon · Device 2', 'Device 2', tankSeries, t.blue),
      _ => ('Suhu udara · Device 1', 'Device 1', tempSeries, t.amber),
    };

    final pumpReading = _latestMetric(c, 'node2', 'pump', '');
    final fan1Reading = _latestMetric(c, 'node1', 'fan1', '');
    final fan2Reading = _latestMetric(c, 'node1', 'fan2', '');

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
                ? 'Pantau kondisi iklim, tanah, dan tandon dalam satu layar ringkas.'
                : 'Gambaran kondisi rumah kaca, media tanam, dan irigasi hari ini.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
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
              if (c.preview)
                const GrowviaBadge('Menunggu data')
              else
                GrowviaBadge(
                  c.liveConnected ? 'Live · MQTT' : 'Live nonaktif',
                  tone: c.liveConnected ? 'green' : 'neutral',
                  dot: true,
                ),
              if (!c.preview)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: c.loadingReadings || c.loadingWorkspace
                      ? null
                      : _refresh,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GrowviaIcon(
                          'refresh',
                          size: 13,
                          color: t.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c.loadingReadings || c.loadingWorkspace
                              ? 'Memuat…'
                              : c.readings.isNotEmpty
                              ? _latestStamp(c.readings)
                              : 'Muat ulang',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: t.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (c.loadingWorkspace)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (c.workspaceError != null) ...[
            const SizedBox(height: 12),
            Notice(
              title: 'Ringkasan server belum dimuat',
              message: c.workspaceError!,
              error: true,
            ),
          ],
          if (c.dataError != null) ...[
            const SizedBox(height: 12),
            Notice(
              title: 'Data belum dapat dimuat',
              message: c.dataError!,
              error: true,
            ),
          ],
          const SizedBox(height: 16),

          // Bagian 1 (Above the fold): Telemetri langsung Device 1 & Device 2.
          _DeviceGroupPanel(
            panelKey: const Key('open-climate'),
            title: 'Iklim · Device 1',
            subtitle: '2x SHT (udara) · 2 kipas',
            icon: 'sun',
            tone: 'amber',
            badges: [
              _ActuatorBadge(label: 'Kipas 1', reading: fan1Reading),
              _ActuatorBadge(label: 'Kipas 2', reading: fan2Reading),
            ],
            onDetail: () =>
                _open(context, NodeDetailPage(controller: c, node: 'node1')),
            child: ResponsiveTiles(
              minimumWidth: 145,
              children: [
                MetricCard(
                  label: 'Suhu udara',
                  unit: '°C',
                  icon: 'thermometer',
                  tone: 'amber',
                  reading: _latestMetric(c, 'node1', 'temperature', '°C'),
                ),
                MetricCard(
                  label: 'Kelembapan udara',
                  unit: '%',
                  icon: 'drop',
                  tone: 'blue',
                  reading: _latestMetric(c, 'node1', 'humidity', '%'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DeviceGroupPanel(
            panelKey: const Key('open-soil'),
            title: 'Tanah & air · Device 2',
            subtitle: '3x sensor tanah · tandon',
            icon: 'drop',
            tone: 'blue',
            badges: [_ActuatorBadge(label: 'Pompa', reading: pumpReading)],
            onDetail: () =>
                _open(context, NodeDetailPage(controller: c, node: 'node2')),
            child: ResponsiveTiles(
              minimumWidth: 145,
              children: [
                MetricCard(
                  label: 'Kelembapan tanah',
                  unit: '%',
                  icon: 'leaf',
                  reading: _latestMetric(c, 'node2', 'soil_moisture', '%'),
                ),
                MetricCard(
                  label: 'Isi tandon',
                  unit: '%',
                  icon: 'tank',
                  tone: 'blue',
                  reading: _latestMetric(c, 'node2', 'water_level', '%'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bagian 2: Grafik tren multi-metrik interaktif.
          _TrendTabs(
            selected: _chartMetric,
            onSelect: (metric) => setState(() => _chartMetric = metric),
          ),
          const SizedBox(height: 10),
          if (chartSeries.isEmpty)
            GrowviaEmptyChart(
              key: _chartMetric == 'temperature'
                  ? const Key('dashboard-temperature-chart')
                  : null,
              title: 'Tren $chartTitle',
              subtitle: 'Riwayat pembacaan sensor',
              node: chartNode,
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
            )
          else
            ReadingChart(
              key: _chartMetric == 'temperature'
                  ? const Key('dashboard-temperature-chart')
                  : ValueKey('dashboard-chart-$_chartMetric'),
              title: chartTitle,
              readings: chartSeries,
              accentColor: chartColor,
            ),
          const SizedBox(height: 16),

          // Bagian 3: Gauge kelembapan akar + Status pompa.
          Panel(
            padding: 16,
            child: Center(
              child: MoistureGauge(
                reading: _latestMetric(c, 'node2', 'soil_moisture', '%'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GrowviaPanel(
            padding: 16,
            title: 'Kontrol pompa',
            subtitle: 'Irigasi / Node2',
            headerTrailing: _ActuatorBadge(label: 'Pompa', reading: pumpReading),
            child: Column(
              children: [
                const GrowviaPumpVisual(),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const GrowviaIcon('power', size: 16),
                    label: const Text('Nyalakan manual'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Kontrol perangkat belum tersedia di mobile. Menyimpan konfigurasi tidak menyalakan pompa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.5, color: t.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bagian 4: Status koneksi & informasi sesi.
          if (c.preview)
            const Notice(
              title: 'Mode pratinjau',
              message:
                  'Bukan sesi masuk. Jelajahi tampilan kebun dan panduan tanpa akun. Data sensor dan pengelolaan server tidak tersedia dalam pratinjau.',
            )
          else ...[
            if (!hasTelemetry && !c.liveConnected) ...[
              GrowviaConnectionNotice(
                onTap: c.isAdmin
                    ? () => _open(context, SystemSettingsPage(controller: c))
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            Notice(
              title: 'Halo, ${c.session!.name}',
              message:
                  'Akun diverifikasi melalui REST API. Data sensor masuk lewat MQTT langsung saat perangkat mengirim, dan riwayatnya tersimpan di server.',
            ),
          ],
          const SizedBox(height: 16),
          GrowviaNodeStatus(
            node1Active: c.readings.any((r) => r.node == 'node1'),
            node2Active: c.readings.any((r) => r.node == 'node2'),
            liveConnected: c.liveConnected,
          ),
          const SizedBox(height: 16),
          // Padanan `.guide-callout` di `petani/dashboard.blade.php`.
          Panel(
            padding: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GrowviaIconTile(icon: 'book', size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Masih bingung baca angka sensor?',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mulai dari panduan singkat soal suhu, tanah, dan cara menyiram.',
                        style: TextStyle(fontSize: 12.5, color: t.secondary),
                      ),
                      const SizedBox(height: 6),
                      GrowviaTextLink(
                        label: 'Pelajari panduan',
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
          if (c.session != null) ...[
            const SizedBox(height: 22),
            GrowviaSectionHeading(
              eyebrow: c.isAdmin ? 'Pengelolaan' : 'Akun & keamanan',
              title: c.isAdmin
                  ? 'Kelola kebun dan pengguna'
                  : 'Profil dan sesi perangkat',
            ),
            if (c.isAdmin) ...[
              if (c.workspace?.counts case final counts?) ...[
                Panel(
                  padding: 16,
                  child: ResponsiveTiles(
                    minimumWidth: 140,
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
              const SizedBox(height: 10),
              GrowviaLinkTile(
                key: const Key('open-activities'),
                title: 'Log aktivitas',
                subtitle: 'Riwayat akun, sesi, dan pengaturan',
                icon: 'clock',
                onTap: () => _open(context, ActivityPage(controller: c)),
              ),
              const SizedBox(height: 10),
              GrowviaLinkTile(
                key: const Key('open-system'),
                title: 'Pengaturan sistem',
                subtitle: 'Target lingkungan dan preferensi tersimpan',
                icon: 'settings',
                onTap: () => _open(context, SystemSettingsPage(controller: c)),
              ),
              const SizedBox(height: 10),
              GrowviaLinkTile(
                key: const Key('open-backup'),
                title: 'Backup database',
                subtitle: 'Jadwal cadangan, unduh berkas, dan status',
                icon: 'archive',
                onTap: () => _open(context, BackupPage(controller: c)),
              ),
              const SizedBox(height: 10),
            ],
            GrowviaLinkTile(
              key: const Key('open-account'),
              title: 'Profil & keamanan',
              subtitle: 'Profil, kata sandi, dan sesi perangkat',
              icon: 'shield',
              onTap: () => _open(context, AccountPage(controller: c)),
            ),
          ],
          if (c.isAdmin) ...[
            const SizedBox(height: 22),
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
                padding: 16,
                child: Text(
                  'Belum ada aktivitas aplikasi yang tercatat. Ini bukan riwayat perangkat.',
                ),
              )
            else
              Panel(
                padding: 16,
                child: Column(
                  children: [
                    for (final activity in c.workspace!.recentActivities)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const GrowviaIconTile(icon: 'clock', size: 32),
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
                                  Text(
                                    activity.actorName,
                                    style: TextStyle(color: t.secondary),
                                  ),
                                  Text(
                                    '${activity.createdAt.toUtc().toIso8601String()} UTC',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: t.muted,
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
          const SizedBox(height: 20),
          Text(
            'Konfigurasi tersimpan bukan konfirmasi kondisi perangkat. Kontrol pompa tetap belum aktif.',
            style: TextStyle(fontSize: 12, color: t.muted),
          ),
        ],
      ),
    );
  }
}

class _DeviceGroupPanel extends StatelessWidget {
  const _DeviceGroupPanel({
    required this.panelKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.badges,
    required this.onDetail,
    required this.child,
  });

  final Key panelKey;
  final String title;
  final String subtitle;
  final String icon;
  final String tone;
  final List<Widget> badges;
  final VoidCallback onDetail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return GrowviaPanel(
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GrowviaIconTile(icon: icon, tone: tone, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: t.secondary),
                    ),
                  ],
                ),
              ),
              InkWell(
                key: panelKey,
                borderRadius: BorderRadius.circular(10),
                onTap: onDetail,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Detail',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: t.green,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GrowviaIcon('arrow', size: 13, color: t.green),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: badges),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ActuatorBadge extends StatelessWidget {
  const _ActuatorBadge({required this.label, required this.reading});
  final String label;
  final Reading? reading;

  @override
  Widget build(BuildContext context) {
    if (reading == null) {
      return GrowviaBadge('$label · Belum ada');
    }
    final on = reading!.value >= 0.5;
    return GrowviaBadge(
      '$label · ${on ? 'Menyala' : 'Mati'}',
      tone: on ? 'green' : 'neutral',
      dot: true,
    );
  }
}

class _TrendTabs extends StatelessWidget {
  const _TrendTabs({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  static const _tabs = <(String, String)>[
    ('temperature', 'Suhu'),
    ('humidity', 'Udara'),
    ('soil_moisture', 'Tanah'),
    ('water_level', 'Tandon'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(12.5) / 12.5;
    Widget tabButton(String id, String label) {
      final active = selected == id;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelect(id),
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? t.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: t.controlLine) : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? t.green : t.secondary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.soft,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 310 || scale > 1.35) {
            return Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final (id, label) in _tabs)
                  IntrinsicWidth(child: tabButton(id, label)),
              ],
            );
          }
          return Row(
            children: [
              for (final (id, label) in _tabs)
                Expanded(child: tabButton(id, label)),
            ],
          );
        },
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

/// Metrik status (pompa) bernilai 0/1 dengan unit `state`; kartu butuh
/// unit kosong supaya dianggap valid dan teks status yang terbaca.
extension _StatusReading on Reading {
  Reading asStateReading() => Reading(
    id: id,
    node: node,
    metric: metric,
    value: value,
    unit: '',
    recordedAt: recordedAt,
  );
}
