import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../ui/charts.dart';
import '../ui/components.dart';
import '../ui/dashboard_components.dart';
import '../ui/growvia_components.dart';
import '../ui/growvia_icon.dart';
import 'guide_page.dart';
import 'system_settings_page.dart';

class NodeDetailPage extends StatefulWidget {
  const NodeDetailPage({
    required this.controller,
    required this.node,
    super.key,
  });
  final AppController controller;
  final String node;

  @override
  State<NodeDetailPage> createState() => _NodeDetailPageState();
}

class _NodeDetailPageState extends State<NodeDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.controller.session != null &&
          widget.controller.workspace == null) {
        loadWorkspaceForDisplay(widget.controller);
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final climate = widget.node == 'node1';
      final settings = c.session == null ? null : c.workspace?.settings;
      final rows = climate
          ? <String, String>{
              'Suhu udara':
                  '${settings?['th_suhu_min'] ?? '—'}–${settings?['th_suhu_max'] ?? '—'} °C',
              'Kelembapan udara':
                  '${settings?['th_hum_min'] ?? '—'}–${settings?['th_hum_max'] ?? '—'}%',
              'Cahaya minimum': '${settings?['th_light_min'] ?? '—'} klux',
              'Kadar CO2':
                  '${settings?['th_co2_min'] ?? '—'}–${settings?['th_co2_max'] ?? '—'} ppm',
            }
          : <String, String>{
              'Mode pompa': settings?['pump_mode'] == 'manual'
                  ? 'Manual'
                  : settings?['pump_mode'] == 'auto'
                  ? 'Otomatis'
                  : '—',
              'Ambang mulai menyiram': '< ${settings?['soil_on'] ?? '—'}%',
              'Ambang berhenti menyiram': '> ${settings?['soil_off'] ?? '—'}%',
              'Tandon minimum': '${settings?['tank_min'] ?? '—'}%',
              'Durasi maksimum': '${settings?['pump_max_run'] ?? '—'} menit',
            };
      final metrics = climate
          ? const <(String, String, String, String)>[
              ('temperature', 'Suhu udara', '°C', 'thermometer'),
              ('humidity', 'Kelembapan udara', '%', 'drop'),
              ('light', 'Intensitas cahaya', 'klux', 'sun'),
              ('co2', 'Kadar CO2', 'ppm', 'leaf'),
            ]
          : const <(String, String, String, String)>[
              ('soil_moisture', 'Kelembapan tanah', '%', 'leaf'),
              ('soil_temperature', 'Suhu tanah', '°C', 'thermometer'),
              ('water_level', 'Isi tandon', '%', 'tank'),
              ('pump', 'Status pompa', '', 'power'),
            ];
      final title = climate ? 'Iklim rumah kaca' : 'Tanah & air';
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          top: false,
          child: PageBody(
            children: [
              PageIntro(
                eyebrow: climate
                    ? 'Node1 / Lingkungan tumbuh'
                    : 'Node2 / Perawatan kebun',
                title: climate
                    ? 'Lingkungan tumbuh yang tepat.'
                    : 'Perhatikan akar dan airnya.',
                description: climate
                    ? 'Suhu, kelembapan, cahaya, dan CO2 dalam satu ruang kerja.'
                    : 'Kondisi akar, persediaan air, dan rencana penyiraman.',
              ),
              const SizedBox(height: 20),
              const Notice(
                title: 'Integrasi sensor belum aktif',
                message: 'Angka sensor dan status perangkat belum tersedia. Target di bawah adalah konfigurasi, bukan hasil pengukuran.',
              ),
              const SizedBox(height: 20),
              ResponsiveTiles(
                minimumWidth: 150,
                children: [
                  for (final metric in metrics)
                    MetricCard(
                      label: metric.$2,
                      unit: metric.$3,
                      icon: metric.$4,
                      reading: c.session == null
                          ? null
                          : c.readings
                                .where(
                                  (r) =>
                                      r.node == widget.node &&
                                      r.metric == metric.$1 &&
                                      r.unit == metric.$3,
                                )
                                .firstOrNull,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              GrowviaSectionHeading(
                title: climate ? 'Target lingkungan' : 'Rencana penyiraman',
                subtitle: 'Konfigurasi tersimpan oleh admin',
              ),
              if (c.loadingWorkspace) const LinearProgressIndicator(),
              if (c.workspaceError != null && c.session != null) ...[
                Notice(
                  title: 'Konfigurasi belum dimuat',
                  message: c.workspaceError!,
                  error: true,
                ),
                TextButton.icon(
                  onPressed: c.loadingWorkspace
                      ? null
                      : () => loadWorkspaceForDisplay(c),
                  icon: const GrowviaIcon('refresh'),
                  label: const Text('Coba lagi'),
                ),
              ],
              if (c.session == null)
                const Notice(
                  title: 'Pratinjau target',
                  message: 'Masuk untuk membaca konfigurasi yang tersimpan di server. Tidak ada ambang contoh yang dianggap sebagai pengaturan kebun.',
                )
              else if (settings != null)
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GrowviaDefinitionList(entries: rows),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum dikirim atau diterapkan ke perangkat. Sesuaikan target dengan tanaman dan kondisi setempat.',
                      ),
                      if (c.isAdmin) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => SystemSettingsPage(controller: c),
                            ),
                          ),
                          icon: const GrowviaIcon('settings'),
                          label: const Text('Atur target dan konfigurasi'),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              ReadingChart(
                readings: c.session == null
                    ? const []
                    : c.readings
                          .where(
                            (r) =>
                                r.node == widget.node &&
                                r.metric ==
                                    (climate
                                        ? 'temperature'
                                        : 'soil_moisture') &&
                                r.unit == (climate ? '°C' : '%'),
                          )
                          .toList(),
              ),
              if (!climate) ...[
                const SizedBox(height: 20),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Kontrol pompa',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: null,
                        icon: const GrowviaIcon('power'),
                        label: const Text('Nyalakan manual'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Kontrol dan riwayat pompa belum tersedia. Menyimpan konfigurasi tidak menyalakan pompa.',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // Catatan singkat yang sama dengan aside di
              // `petani/node1.blade.php` dan `petani/node2.blade.php`.
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      climate ? 'Catatan kebun' : 'Perawatan sederhana',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      climate
                          ? 'Udaranya juga perlu diperhatikan.'
                          : 'Cek tandon berkala ya.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      climate
                          ? 'Ventilasi, naungan, dan jarak tanam ikut memengaruhi tempat tumbuh. Sesuaikan perawatan dengan jenis tanamanmu.'
                          : 'Pastikan air cukup dan selang tidak mampet. Kabari admin kalau ada yang bocor atau pompa bermasalah.',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GrowviaTextLink(
                        label: climate
                            ? 'Baca panduan'
                            : 'Panduan penyiraman',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Edukasi')),
                              body: const SafeArea(
                                top: false,
                                child: GuidePage(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GrowviaLinkTile(
                title: 'Belajar dari kebun',
                subtitle: climate
                    ? 'Ventilasi, naungan, dan kebutuhan tanaman.'
                    : 'Kalibrasi tanah, drainase, dan perawatan tandon.',
                icon: 'book',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Edukasi')),
                      body: const SafeArea(top: false, child: GuidePage()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
