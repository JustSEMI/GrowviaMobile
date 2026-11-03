import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_controller.dart';
import '../data/history.dart';
import '../data/reading.dart';
import '../ui/charts.dart';
import '../ui/components.dart';
import '../ui/growvia_icon.dart';
import '../ui/management_components.dart';

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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final records = _filtered;
    final matching = records.where((r) => r.metric == _metric).toList();
    final seriesNode = matching.isNotEmpty ? matching.first.node : null;
    final series = matching.where((r) => r.node == seriesNode).toList();
    return PageBody(
      children: [
        const PageIntro(
          eyebrow: 'Data tersimpan',
          title: 'Riwayat kebun',
          description:
              'Baca perubahan kondisi kebun dari data yang sudah tercatat.',
        ),
        const SizedBox(height: 24),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ManagementSelector(
                id: 'history-node-filter',
                label: 'Area pembacaan',
                value: _node,
                options: const {
                  'all': 'Semua node',
                  'node1': 'Node1 · Iklim',
                  'node2': 'Node2 · Tanah & air',
                },
                onChanged: (value) => setState(() {
                  _node = value;
                  _exportMessage = null;
                }),
              ),
              const SizedBox(height: 16),
              ManagementSelector(
                id: 'history-metric-filter',
                label: 'Parameter grafik',
                value: _metric,
                options: const {
                  'temperature': 'Suhu udara',
                  'humidity': 'Kelembapan udara',
                  'soil_moisture': 'Kelembapan tanah',
                  'water_level': 'Isi tandon',
                },
                onChanged: (value) => setState(() => _metric = value),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (buttonContext) => OutlinedButton.icon(
                  onPressed: records.isEmpty || _exporting
                      ? null
                      : () => _export(buttonContext),
                  icon: const GrowviaIcon('arrow-up'),
                  label: Text(_exporting ? 'Menyiapkan CSV…' : 'Ekspor CSV'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'CSV berisi ${records.length} pembacaan yang sudah dimuat, mengikuti filter node. Parameter grafik tidak membatasi CSV.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_exportMessage != null) ...[
                const SizedBox(height: 12),
                Text(_exportMessage!, semanticsLabel: _exportMessage),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (controller.dataError != null) ...[
          Notice(
            title: 'Riwayat belum dapat dimuat',
            message: controller.dataError!,
            error: true,
          ),
          const SizedBox(height: 12),
        ],
        if (!controller.preview) ...[
          TextButton.icon(
            onPressed: controller.loadingReadings ? null : controller.refresh,
            icon: const GrowviaIcon('refresh'),
            label: Text(
              controller.loadingReadings ? 'Memuat…' : 'Muat ulang dari server',
            ),
          ),
          const SizedBox(height: 12),
        ],
        ReadingChart(key: const Key('history-chart'), readings: series),
        const SizedBox(height: 20),
        if (records.isEmpty)
          Panel(
            child: Column(
              children: [
                GrowviaIcon(
                  'chart',
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada riwayat sensor',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Data berasal dari REST API. Grafik dan CSV tidak dibuat dari data contoh.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          Text(
            '${records.length} pembacaan termuat',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final reading in records.take(100)) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${reading.label} · ${reading.node}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${reading.value} ${reading.unit}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${reading.recordedAt.toIso8601String()} UTC',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (records.length > 100)
            const Text(
              'Daftar menampilkan 100 pembacaan terbaru. CSV mencakup seluruh pembacaan yang sudah dimuat.',
            ),
        ],
      ],
    );
  }
}
