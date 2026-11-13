import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/tokens.dart';
import '../data/reading.dart';
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
    this.nowOverride,
    super.key,
  });
  final AppController controller;
  final String node;

  /// Hanya untuk pengujian: mengunci "sekarang" agar rentang deterministik.
  final DateTime? nowOverride;

  @override
  State<NodeDetailPage> createState() => _NodeDetailPageState();
}

class _NodeDetailPageState extends State<NodeDetailPage> {
  /// Rentang grafik & ringkasan aktif, dalam jam (24 jam / 7 hari).
  int _rangeHours = 24;

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
              ('temperature2', 'Suhu udara 2', '°C', 'thermometer'),
              ('humidity2', 'Kelembapan udara 2', '%', 'drop'),
              ('fan1', 'Kipas 1', '', 'power'),
              ('fan2', 'Kipas 2', '', 'power'),
            ]
          : const <(String, String, String, String)>[
              ('soil_moisture', 'Kelembapan tanah', '%', 'leaf'),
              ('soil_moisture2', 'Kelembapan tanah 2', '%', 'leaf'),
              ('soil_moisture3', 'Kelembapan tanah 3', '%', 'leaf'),
              ('water_level', 'Isi tandon', '%', 'tank'),
              ('pump', 'Status pompa', '', 'power'),
            ];
      final title = climate ? 'Iklim rumah kaca' : 'Tanah & air';
      final now = (widget.nowOverride ?? DateTime.now()).toUtc();
      final cutoff = now.subtract(Duration(hours: _rangeHours));
      final rangeLabel = _rangeHours == 24 ? '24 jam' : '7 hari';
      final inRange = c.session == null
          ? const <Reading>[]
          : c.readings
                .where(
                  (r) => r.node == widget.node && r.recordedAt.isAfter(cutoff),
                )
                .toList();
      final byMetric = <String, List<Reading>>{};
      for (final reading in inRange) {
        (byMetric[reading.metric] ??= []).add(reading);
      }
      // Metrik status (pompa/kipas) bernilai 0/1, tidak digambarkan trennya.
      const stateMetrics = {'pump', 'fan1', 'fan2'};
      final primary = climate ? 'temperature' : 'soil_moisture';
      final primaryLabel = metrics.firstWhere((m) => m.$1 == primary).$2;
      final summaryEntries = <String, String>{
        for (final entry in byMetric.entries)
          if (!stateMetrics.contains(entry.key))
            '${entry.value.first.label} (${entry.value.first.unit})':
                'Terakhir ${_fmt(entry.value.first.value)} · '
                'Min–maks ${_fmt(_min(entry.value))}–${_fmt(_max(entry.value))} · '
                'Rata-rata ${_fmt(_avg(entry.value))}',
      };
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
                    ? 'Suhu, kelembapan, dan kipas dalam satu ruang kerja.'
                    : 'Kondisi akar, persediaan air, dan rencana penyiraman.',
              ),
              const SizedBox(height: 20),
              if (inRange.isEmpty)
                const Notice(
                  title: 'Integrasi sensor belum aktif',
                  message:
                      'Angka sensor dan status perangkat belum tersedia. Target di bawah adalah konfigurasi, bukan hasil pengukuran.',
                )
              else
                Notice(
                  title: 'Data sensor tersimpan',
                  success: true,
                  message:
                      '${inRange.length} pembacaan node ini dalam rentang $rangeLabel. Sumber REST API Laravel, bukan realtime.',
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
                      reading: _metricReading(c, metric.$1, metric.$3),
                      valueText: _metricValueText(c, metric.$1, metric.$3),
                    ),
                  // Metrik tambahan yang dikirim node tapi belum ada di
                  // daftar utama (sensor kedua, kipas, dll).
                  for (final entry in byMetric.entries)
                    if (!metrics.any((m) => m.$1 == entry.key))
                      MetricCard(
                        label: entry.value.first.label,
                        unit: entry.value.first.unit,
                        icon: _iconFor(entry.key),
                        tone: 'neutral',
                        reading: entry.value.first,
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
              GrowviaSectionHeading(
                title: 'Grafik pembacaan',
                subtitle: rangeLabel,
              ),
              const SizedBox(height: 8),
              _RangePills(
                value: _rangeHours,
                onChanged: (hours) => setState(() => _rangeHours = hours),
              ),
              const SizedBox(height: 16),
              // Grafik metrik utama selalu tampil, kosong pun mengikuti
              // konvensi `<x-empty-chart>` di web.
              ReadingChart(
                key: Key('node-chart-$primary'),
                title: '$primaryLabel · $rangeLabel',
                readings: byMetric[primary] ?? const [],
              ),
              for (final entry in byMetric.entries)
                if (entry.key != primary &&
                    !stateMetrics.contains(entry.key)) ...[
                  const SizedBox(height: 12),
                  ReadingChart(
                    title: '${entry.value.first.label} · $rangeLabel',
                    readings: entry.value,
                  ),
                ],
              const SizedBox(height: 24),
              GrowviaSectionHeading(
                title: 'Ringkasan rentang',
                subtitle: rangeLabel,
              ),
              const SizedBox(height: 12),
              Panel(
                child: summaryEntries.isEmpty
                    ? const Text('Belum ada pembacaan pada rentang ini.')
                    : GrowviaDefinitionList(entries: summaryEntries),
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

  static double _min(List<Reading> list) =>
      list.map((r) => r.value).reduce((a, b) => a < b ? a : b);

  /// Pembacaan terbaru untuk satu metrik. Metrik status (unit kosong di
  /// daftar) dicocokkan tanpa peduli unit karena nilainya `state`.
  Reading? _metricReading(AppController c, String metric, String unit) {
    if (c.session == null) return null;
    for (final r in c.readings) {
      if (r.node == widget.node && r.metric == metric && (unit.isEmpty || r.unit == unit)) {
        return unit.isEmpty
            ? Reading(
                id: r.id,
                node: r.node,
                metric: r.metric,
                value: r.value,
                unit: '',
                recordedAt: r.recordedAt,
              )
            : r;
      }
    }
    return null;
  }

  String? _metricValueText(AppController c, String metric, String unit) {
    if (unit.isNotEmpty) return null;
    final reading = _metricReading(c, metric, unit);
    if (reading == null) return null;
    return reading.value >= 0.5 ? 'Menyala' : 'Mati';
  }

  static double _max(List<Reading> list) =>
      list.map((r) => r.value).reduce((a, b) => a > b ? a : b);

  static double _avg(List<Reading> list) =>
      list.map((r) => r.value).reduce((a, b) => a + b) / list.length;

  static String _fmt(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  static String _iconFor(String metric) => switch (metric) {
    'temperature2' => 'thermometer',
    'humidity2' => 'drop',
    final m when m.startsWith('soil_moisture') => 'leaf',
    final m when m.startsWith('fan') => 'power',
    _ => 'leaf',
  };
}

/// Pil rentang gaya `.chart-period` web: kecil, garis tipis, terpilih hijau.
class _RangePills extends StatelessWidget {
  const _RangePills({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _options = <(int, String)>[(24, '24 jam'), (168, '7 hari')];

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Wrap(
      spacing: 8,
      children: [
        for (final (hours, label) in _options) _pill(t, hours, label),
      ],
    );
  }

  Widget _pill(GrowviaTokens t, int hours, String label) {
    final selected = hours == value;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () => onChanged(hours),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? t.paleGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: selected ? t.green : t.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? t.green : t.secondary,
            ),
          ),
        ),
      ),
    );
  }
}
