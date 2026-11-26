import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/tokens.dart';
import '../data/api_client.dart';
import '../data/reading.dart';
import 'growvia_components.dart';

Future<void> loadWorkspaceForDisplay(AppController controller) async {
  try {
    await controller.loadWorkspace();
  } on ApiException {
    // Controller mempertahankan pesan error atau menutup sesi yang tidak valid.
  }
}

/// Grid sederhana yang menumpuk saat ruang atau text scale tidak cukup.
class ResponsiveTiles extends StatelessWidget {
  const ResponsiveTiles({
    required this.children,
    this.minimumWidth = 240,
    super.key,
  });
  final List<Widget> children;
  final double minimumWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = constraints.maxWidth >= minimumWidth * 2 && scale < 1.5
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// Padanan `components/metric-tile.blade.php`.
class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.icon,
    this.unit = '',
    this.valueText,
    this.tone = 'green',
    this.reading,
    this.note = 'Menunggu sensor',
    super.key,
  });
  final String label;

  /// Nama ikon Growvia, sama dengan `<x-icon name="...">` di web.
  final String icon;

  final String unit;

  /// `green`, `blue`, `amber`, atau `neutral` (`.icon-tile--*`).
  final String tone;

  final Reading? reading;
  final String note;

  /// Teks nilai manual untuk metrik status (pompa/kipas). Kalau diisi,
  /// angka mentah tidak ditampilkan.
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    final tokens = GrowviaTokens.of(context);
    final valid =
        reading != null && reading!.value.isFinite && reading!.unit == unit;
    final colors = tokens.tone(tone);
    final double? fraction = !valid
        ? null
        : unit == '%'
        ? (reading!.value / 100).clamp(0.0, 1.0)
        : unit == '°C'
        ? (reading!.value / 50).clamp(0.0, 1.0)
        : null;
    final primaryText = valid
        ? (valueText ?? reading!.value.toStringAsFixed(1))
        : '—';
    final stamp = valid
        ? '${reading!.recordedAt.toUtc().hour.toString().padLeft(2, '0')}:'
              '${reading!.recordedAt.toUtc().minute.toString().padLeft(2, '0')} UTC'
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: tokens.scrim.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GrowviaIconTile(icon: icon, tone: tone, size: 32),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 12.5,
                    height: 1.25,
                    color: tokens.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: primaryText,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -0.6,
                    color: valid ? tokens.ink : colors.foreground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.secondary,
                    ),
                  ),
              ],
            ),
          ),
          if (fraction != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: tokens.chartGrid),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fraction,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.foreground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            valid ? 'Terakhir $stamp' : note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: tokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}
