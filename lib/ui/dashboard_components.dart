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
    final c = Theme.of(context).colorScheme;
    final tokens = GrowviaTokens.of(context);
    final valid =
        reading != null && reading!.value.isFinite && reading!.unit == unit;
    final colors = tokens.tone(tone);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.background, tokens.surface],
        ),
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: tokens.scrim.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.textScalerOf(context).scale(44),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GrowviaIconTile(icon: icon, tone: tone, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${valid ? (valueText ?? reading!.value.toStringAsFixed(1)) : '—'}${unit.isEmpty ? '' : ' $unit'}',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: valid ? tokens.ink : colors.foreground),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.textScalerOf(context).scale(32),
            ),
            child: Text(
              valid ? 'Data tersimpan · bukan realtime' : note,
              style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
