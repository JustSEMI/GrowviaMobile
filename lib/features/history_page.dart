import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_controller.dart';
import '../core/tokens.dart';
import '../data/history.dart';
import '../data/reading.dart';
import '../ui/charts.dart';
import '../ui/components.dart';
import '../ui/growvia_components.dart';
import '../ui/growvia_icon.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _node = 'all';
  String _metric = 'temperature';
  bool _exporting = false;
  String? _exportMessage;

  List<Reading> get _filtered => widget.controller.readings
      .where((r) => _node == 'all' || r.node == _node)
      .toList();

  Future<void> _export(BuildContext buttonContext) async {
    final rows = _filtered;
    if (_exporting || rows.isEmpty) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    setState(() {
      _exporting = true;
      _exportMessage = null;
    });
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Riwayat Growvia',
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(readingsToCsv(rows))),
              mimeType: 'text/csv',
            ),
          ],
          fileNameOverrides: ['growvia-riwayat.csv'],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
          downloadFallbackEnabled: true,
        ),
      );
      if (!mounted) return;
      setState(
        () => _exportMessage = result.status == ShareResultStatus.dismissed
            ? 'Ekspor dibatalkan.'
            : 'Berkas CSV disiapkan. Penyimpanan akhir mengikuti aplikasi tujuan yang kamu pilih.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _exportMessage = 'CSV belum dapat dibagikan. Coba kembali.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  static const _nodeMetrics = <String, List<(String, String)>>{
    'node1': [
      ('temperature', 'Suhu 1'),
      ('humidity', 'Lembap 1'),
      ('temperature2', 'Suhu 2'),
      ('humidity2', 'Lembap 2'),
    ],
    'node2': [
      ('soil_moisture', 'Tanah 1'),
      ('soil_moisture2', 'Tanah 2'),
      ('soil_moisture3', 'Tanah 3'),
      ('water_level', 'Tandon'),
    ],
  };

  List<(String, String)> _metricsForNode(String node) => switch (node) {
    'node1' => _nodeMetrics['node1']!,
    'node2' => _nodeMetrics['node2']!,
    _ => [..._nodeMetrics['node1']!, ..._nodeMetrics['node2']!],
  };

  String _nodeLabel(String node) => switch (node) {
    'node1' => 'Device 1',
    'node2' => 'Device 2',
    _ => node,
  };

  void _selectNode(String id) {
    final allowed = _metricsForNode(id);
    setState(() {
      _node = id;
      _exportMessage = null;
      if (!allowed.any((item) => item.$1 == _metric)) {
        _metric = allowed.first.$1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final t = GrowviaTokens.of(context);
    final records = _filtered;
    final metricOptions = _metricsForNode(_node);
    final matching = records.where((r) => r.metric == _metric).toList();
    final seriesNode = matching.isNotEmpty ? matching.first.node : null;
    final series = matching.where((r) => r.node == seriesNode).toList();
    const nodeOptions = <(String, String)>[
      ('all', 'Semua'),
      ('node1', 'Device 1'),
      ('node2', 'Device 2'),
    ];
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return PageBody(
      children: [
        const PageIntro(
          eyebrow: 'Data tersimpan',
          title: 'Riwayat sensor',
          description:
              'Pilih perangkat dan sensor untuk melihat grafik maupun ekspor CSV.',
        ),
        const SizedBox(height: 16),
        Panel(
          padding: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final badge = GrowviaBadge(
                    '${records.length} data',
                    tone: records.isEmpty ? 'neutral' : 'green',
                    uppercase: false,
                  );
                  if (scale > 1.35 || constraints.maxWidth < 250) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Perangkat',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: t.secondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        badge,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Perangkat',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: t.secondary,
                          ),
                        ),
                      ),
                      badge,
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Container(
                key: const Key('history-node-filter'),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: t.soft,
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chipScale =
                        MediaQuery.textScalerOf(context).scale(12.5) / 12.5;
                    Widget nodeButton(String id, String label) {
                      final active = _node == id;
                      return Material(
                        color: active ? t.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _selectNode(id),
                          child: Container(
                            alignment: Alignment.center,
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              border: active
                                  ? Border.all(color: t.controlLine)
                                  : null,
                            ),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight:
                                    active ? FontWeight.w700 : FontWeight.w500,
                                color: active ? t.green : t.secondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    if (constraints.maxWidth < 270 || chipScale > 1.35) {
                      return Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final (id, label) in nodeOptions)
                            IntrinsicWidth(child: nodeButton(id, label)),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (final (id, label) in nodeOptions)
                          Expanded(child: nodeButton(id, label)),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sensor grafik',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.secondary,
                ),
              ),
              const SizedBox(height: 8),
              if (scale > 1.35)
                Wrap(
                  key: const Key('history-metric-filter'),
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (key, label) in metricOptions)
                      _MetricChip(
                        label: label,
                        selected: _metric == key,
                        onTap: () => setState(() => _metric = key),
                      ),
                  ],
                )
              else
                SingleChildScrollView(
                  key: const Key('history-metric-filter'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < metricOptions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        _MetricChip(
                          label: metricOptions[i].$2,
                          selected: _metric == metricOptions[i].$1,
                          onTap: () =>
                              setState(() => _metric = metricOptions[i].$1),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Divider(height: 1, color: t.line),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Builder(
                    builder: (buttonContext) => OutlinedButton.icon(
                      onPressed: records.isEmpty || _exporting
                          ? null
                          : () => _export(buttonContext),
                      icon: const GrowviaIcon('arrow-up', size: 17),
                      label: Text(
                        _exporting ? 'Menyiapkan CSV…' : 'Ekspor CSV',
                      ),
                    ),
                  ),
                  if (!controller.preview)
                    TextButton.icon(
                      onPressed: controller.loadingReadings
                          ? null
                          : controller.refresh,
                      icon: const GrowviaIcon('refresh', size: 16),
                      label: Text(
                        controller.loadingReadings
                            ? 'Memuat…'
                            : 'Muat ulang',
                      ),
                    ),
                ],
              ),
              if (_exportMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _exportMessage!,
                  semanticsLabel: _exportMessage,
                  style: TextStyle(fontSize: 12.5, color: t.secondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (controller.dataError != null) ...[
          Notice(
            title: 'Riwayat belum dapat dimuat',
            message: controller.dataError!,
            error: true,
          ),
          const SizedBox(height: 12),
        ],
        ReadingChart(
          key: const Key('history-chart'),
          readings: series,
          accentColor: _metric == 'temperature' || _metric == 'temperature2'
              ? t.amber
              : _metric.startsWith('soil_moisture')
              ? t.green
              : t.blue,
        ),
        const SizedBox(height: 16),
        if (records.isEmpty)
          Panel(
            padding: 20,
            child: Column(
              children: [
                GrowviaIcon('chart', size: 36, color: t.green),
                const SizedBox(height: 12),
                Text(
                  'Belum ada riwayat sensor',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Data berasal dari REST API. Grafik dan CSV tidak dibuat dari data contoh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: t.secondary),
                ),
              ],
            ),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${records.length} pembacaan termuat',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Terbaru dulu',
                style: TextStyle(fontSize: 12, color: t.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final reading in records.take(100)) ...[
            Panel(
              padding: 14,
              child: Row(
                children: [
                  GrowviaIconTile(
                    icon: _iconForMetric(reading.metric),
                    tone: _toneForMetric(reading.metric),
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${reading.label} · ${_nodeLabel(reading.node)}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${reading.recordedAt.toIso8601String()} UTC',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: t.muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${reading.value} ${reading.unit}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (records.length > 100)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Daftar menampilkan 100 pembacaan terbaru. CSV mencakup seluruh pembacaan yang sudah dimuat.',
                style: TextStyle(fontSize: 12, color: t.muted),
              ),
            ),
        ],
      ],
    );
  }

  static String _iconForMetric(String metric) => switch (metric) {
    'temperature' || 'temperature2' => 'thermometer',
    'humidity' || 'humidity2' => 'drop',
    'water_level' => 'tank',
    'pump' || 'fan1' => 'power',
    _ => 'leaf',
  };

  static String _toneForMetric(String metric) => switch (metric) {
    'temperature' || 'temperature2' => 'amber',
    'humidity' || 'humidity2' || 'water_level' => 'blue',
    'pump' || 'fan1' => 'neutral',
    _ => 'green',
  };
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? t.paleGreen : t.soft,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? t.green : t.line,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? t.green : t.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
