import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../data/reading.dart';
import 'components.dart';

String _nodeLabel(String node) => switch (node) {
  'node1' => 'Device 1',
  'node2' => 'Device 2',
  _ => node,
};

class ReadingChart extends StatelessWidget {
  const ReadingChart({
    required this.readings,
    this.title,
    this.accentColor,
    super.key,
  });
  final List<Reading> readings;

  /// Judul kustom (mis. `Suhu udara · 24 jam`). Bila kosong, judul diambil
  /// dari pembacaan pertama seperti sebelumnya.
  final String? title;

  /// Warna aksen garis & area kurva (mengikuti metrik, bawaan `tokens.green`).
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final ordered = [...readings]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final scheme = Theme.of(context).colorScheme;
    final tokens = GrowviaTokens.of(context);
    final lineColor = accentColor ?? tokens.green;
    return Panel(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ??
                          (ordered.isEmpty
                              ? 'Tren pembacaan'
                              : '${ordered.first.label} · ${_nodeLabel(ordered.first.node)}'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ordered.isEmpty
                          ? 'Belum ada data untuk digambarkan.'
                          : '${ordered.length} pembacaan · ${ordered.first.unit} · waktu UTC',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (ordered.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.soft,
                    border: Border.all(color: tokens.line),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_fmt(ordered.last.value)} ${ordered.first.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
          if (ordered.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: tokens.soft,
                border: Border.all(color: tokens.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _ChartStat(
                    label: 'Minimum',
                    value: '${_fmt(_min(ordered))} ${ordered.first.unit}',
                  ),
                  _ChartStat(
                    label: 'Rata-rata',
                    value: '${_fmt(_avg(ordered))} ${ordered.first.unit}',
                  ),
                  _ChartStat(
                    label: 'Maksimum',
                    value: '${_fmt(_max(ordered))} ${ordered.first.unit}',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Semantics(
            label: ordered.isEmpty
                ? 'Grafik kosong, belum ada data'
                : 'Grafik ${ordered.first.label}. Nilai pertama ${ordered.first.value}, nilai terakhir ${ordered.last.value} ${ordered.last.unit}. Angka lengkap tersedia pada daftar riwayat.',
            image: true,
            child: ExcludeSemantics(
              child: SizedBox(
                height: 164,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter(
                    ordered,
                    lineColor,
                    tokens.chartGrid,
                    tokens.surface,
                  ),
                ),
              ),
            ),
          ),
          if (ordered.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Rentang data: ${_fmt(_min(ordered))}–${_fmt(_max(ordered))} ${ordered.first.unit} · '
              'Rata-rata ${_fmt(_avg(ordered))} ${ordered.first.unit}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                children: [
                  Text(
                    _time(ordered.first.recordedAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: tokens.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _time(ordered.last.recordedAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: tokens.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (ordered.length == 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Satu titik belum menunjukkan tren.',
                  style: TextStyle(fontSize: 12, color: tokens.secondary),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _time(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  static double _min(List<Reading> readings) =>
      readings.map((r) => r.value).reduce(math.min);

  static double _max(List<Reading> readings) =>
      readings.map((r) => r.value).reduce(math.max);

  static double _avg(List<Reading> readings) =>
      readings.map((r) => r.value).reduce((a, b) => a + b) / readings.length;

  static String _fmt(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class _ChartStat extends StatelessWidget {
  const _ChartStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: t.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: t.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.readings, this.color, this.grid, this.surface);
  final List<Reading> readings;
  final Color color;
  final Color grid;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(
      8,
      10,
      math.max(size.width - 16, 1),
      math.max(size.height - 20, 1),
    );
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    for (var line = 0; line <= 3; line++) {
      final y = plot.top + plot.height * line / 3;
      var x = plot.left;
      while (x < plot.right) {
        final end = math.min(x + dash, plot.right);
        canvas.drawLine(Offset(x, y), Offset(end, y), gridPaint);
        x = end + gap;
      }
    }
    if (readings.isEmpty) return;
    final minimum = readings.map((r) => r.value).reduce(math.min);
    final maximum = readings.map((r) => r.value).reduce(math.max);
    final firstTime = readings.first.recordedAt.millisecondsSinceEpoch;
    final duration =
        readings.last.recordedAt.millisecondsSinceEpoch - firstTime;
    final span = maximum - minimum;
    final padding = span == 0 ? math.max(minimum.abs() * .05, 1) : span * .18;
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

    final curve = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      curve.lineTo(points[1].dx, points[1].dy);
    } else if (points.length > 2) {
      for (var i = 0; i < points.length - 1; i++) {
        final current = points[i];
        final next = points[i + 1];
        final ctrlX = (current.dx + next.dx) / 2;
        curve.cubicTo(ctrlX, current.dy, ctrlX, next.dy, next.dx, next.dy);
      }
    }

    if (points.length >= 2) {
      final fill = Path.from(curve)
        ..lineTo(points.last.dx, plot.bottom)
        ..lineTo(points.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.01),
            ],
          ).createShader(plot),
      );
      canvas.drawPath(
        curve,
        Paint()
          ..color = color
          ..strokeWidth = 2.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
    }

    final showDots = points.length <= 24;
    if (showDots) {
      for (final point in points) {
        canvas.drawCircle(point, 4.5, Paint()..color = surface);
        canvas.drawCircle(point, 3.0, Paint()..color = color);
      }
    } else {
      canvas.drawCircle(points.last, 5.0, Paint()..color = surface);
      canvas.drawCircle(points.last, 3.4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.readings != readings ||
      oldDelegate.color != color ||
      oldDelegate.grid != grid ||
      oldDelegate.surface != surface;
}

class MoistureGauge extends StatelessWidget {
  const MoistureGauge({required this.reading, super.key});
  final Reading? reading;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = GrowviaTokens.of(context);
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
              width: 196,
              height: 132,
              child: CustomPaint(
                painter: _SemiGaugePainter(
                  fraction: valid ? value / 100 : 0,
                  trackColor: t.chartGrid,
                  activeColor: t.green,
                ),
                child: Align(
                  alignment: const Alignment(0, 0.45),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        valid ? '${value.toStringAsFixed(0)}%' : '—',
                        textScaler: TextScaler.noScaling,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: 32,
                          color: valid ? t.ink : t.green,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'kelembapan tanah',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(fontSize: 12, color: t.secondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          valid
              ? 'Pembacaan tersimpan · MQTT langsung saat aktif'
              : 'Belum ada pembacaan',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          valid
              ? 'Terakhir: ${reading!.recordedAt.toIso8601String()} UTC'
              : 'Menunggu data sensor yang valid. Tidak ada angka simulasi.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SemiGaugePainter extends CustomPainter {
  const _SemiGaugePainter({
    required this.fraction,
    required this.trackColor,
    required this.activeColor,
  });

  final double fraction;
  final Color trackColor;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final radius = math.min(size.width / 2, size.height) - stroke * 1.1;
    final center = Offset(size.width / 2, size.height * 0.72);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = math.pi * 0.94;
    const totalSweep = math.pi * 1.12;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(rect, startAngle, totalSweep, false, trackPaint);

    if (fraction > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      canvas.drawArc(
        rect,
        startAngle,
        totalSweep * fraction.clamp(0.0, 1.0),
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SemiGaugePainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.activeColor != activeColor;
}
