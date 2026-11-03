import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/reading.dart';
import 'components.dart';

class ReadingChart extends StatelessWidget {
  const ReadingChart({required this.readings, super.key});
  final List<Reading> readings;

  @override
  Widget build(BuildContext context) {
    final ordered = [...readings]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final scheme = Theme.of(context).colorScheme;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ordered.isEmpty
                ? 'Tren pembacaan'
                : '${ordered.first.label} · ${ordered.first.node}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            ordered.isEmpty
                ? 'Belum ada data untuk digambarkan.'
                : '${ordered.length} pembacaan · ${ordered.first.unit} · waktu UTC',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: ordered.isEmpty
                ? 'Grafik kosong, belum ada data'
                : 'Grafik ${ordered.first.label}. Nilai pertama ${ordered.first.value}, nilai terakhir ${ordered.last.value} ${ordered.last.unit}. Angka lengkap tersedia pada daftar riwayat.',
            image: true,
            child: ExcludeSemantics(
              child: SizedBox(
                height: 156,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter(
                    ordered,
                    scheme.primary,
                    scheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
          if (ordered.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Rentang data: ${ordered.map((r) => r.value).reduce(math.min)}–${ordered.map((r) => r.value).reduce(math.max)} ${ordered.first.unit}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              children: [
                Text(
                  _time(ordered.first.recordedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _time(ordered.last.recordedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (ordered.length == 1)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Satu titik belum menunjukkan tren.'),
              ),
          ],
        ],
      ),
    );
  }

  String _time(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.readings, this.color, this.grid);
  final List<Reading> readings;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(
      8,
      8,
      math.max(size.width - 16, 1),
      math.max(size.height - 16, 1),
    );
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var line = 0; line <= 3; line++) {
      final y = plot.top + plot.height * line / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }
    if (readings.isEmpty) return;
    final minimum = readings.map((r) => r.value).reduce(math.min);
    final maximum = readings.map((r) => r.value).reduce(math.max);
    final firstTime = readings.first.recordedAt.millisecondsSinceEpoch;
    final duration =
        readings.last.recordedAt.millisecondsSinceEpoch - firstTime;
    final span = maximum - minimum;
    final padding = span == 0 ? math.max(minimum.abs() * .05, 1) : span * .15;
    final lower = minimum - padding;
    final upper = maximum + padding;
    final points = readings
        .map(
          (r) => Offset(
            duration == 0
                ? plot.center.dx
                : plot.left +
                      (r.recordedAt.millisecondsSinceEpoch - firstTime) /
                          duration *
                          plot.width,
            plot.bottom - (r.value - lower) / (upper - lower) * plot.height,
          ),
        )
        .toList();
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    for (final point in points) {
      canvas.drawCircle(point, 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.readings != readings ||
      oldDelegate.color != color ||
      oldDelegate.grid != grid;
}

class MoistureGauge extends StatelessWidget {
  const MoistureGauge({required this.reading, super.key});
  final Reading? reading;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final value = reading?.value;
    final valid = value != null && value.isFinite && value >= 0 && value <= 100;
    return Column(
      children: [
        Semantics(
          label: valid
              ? 'Kelembapan tanah, ${value.toStringAsFixed(1)} persen'
              : 'Belum ada pembacaan kelembapan tanah',
          child: ExcludeSemantics(
            child: SizedBox(
              width: 164,
              height: 164,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: valid ? value / 100 : 0,
                      strokeWidth: 12,
                      backgroundColor: c.outlineVariant,
                      color: c.primary,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        valid ? '${value.toStringAsFixed(0)}%' : '—',
                        textScaler: TextScaler.noScaling,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      Text(
                        'kelembapan tanah',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          valid
              ? 'Pembacaan tersimpan · bukan realtime'
              : 'Belum ada pembacaan',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          valid
              ? 'Terakhir: ${reading!.recordedAt.toIso8601String()} UTC'
              : 'Menunggu data sensor yang valid. Tidak ada angka simulasi.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}
