import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'growvia_icon.dart';
import 'svg_path.dart';

/// Komponen Growvia yang mencerminkan komponen Blade di web.
///
/// Setiap widget di sini punya padanan langsung di
/// `Growvia/resources/views/components/`, memakai [GrowviaTokens] yang sama,
/// sehingga tampilan mobile mengikuti web tanpa menyalin nilai warna.

/// Padanan `components/badge.blade.php`.
class GrowviaBadge extends StatelessWidget {
  const GrowviaBadge(
    this.label, {
    this.tone = 'neutral',
    this.dot = false,
    super.key,
  });

  final String label;

  /// `green`, `blue`, `amber`, `red`, atau `neutral` (bawaan web).
  final String tone;

  /// Menampilkan titik kecil di depan label (`.badge-dot`).
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    final colors = t.tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: colors.foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                height: 1.2,
                color: colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris judul dengan aksi di kanan.
///
/// Menumpuk vertikal saat text scale besar atau ruang sempit, supaya judul
/// dan aksi tidak saling mendesak (penyebab overflow pada scale 2.0).
class _HeadRow extends StatelessWidget {
  const _HeadRow({required this.lead, this.trail});

  final Widget lead;
  final Widget? trail;

  @override
  Widget build(BuildContext context) {
    if (trail == null) return lead;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (scale > 1.4 || constraints.maxWidth < 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [lead, const SizedBox(height: 10), trail!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: lead),
            const SizedBox(width: 16),
            Flexible(child: trail!),
          ],
        );
      },
    );
  }
}

/// Padanan `.icon-tile` / `.icon-tile--*` di web.
class GrowviaIconTile extends StatelessWidget {
  const GrowviaIconTile({
    required this.icon,
    this.tone = 'green',
    this.size = 34,
    super.key,
  });

  final String icon;
  final String tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    final colors = t.tone(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: GrowviaIcon(icon, size: size * 0.5, color: colors.foreground),
      ),
    );
  }
}

/// Padanan `.panel` + `.panel-header` / `.panel-body` / `.panel-footer`.
class GrowviaPanel extends StatelessWidget {
  const GrowviaPanel({
    required this.child,
    this.title,
    this.subtitle,
    this.headerTrailing,
    this.footer,
    this.padding = 20,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? headerTrailing;
  final Widget? footer;

  /// Padding isi panel; web memakai 24px, layar kecil 20px.
  final double padding;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: t.scrim.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: _HeadRow(
                lead: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        letterSpacing: -0.4,
                        color: t.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: t.secondary),
                      ),
                    ],
                  ],
                ),
                trail: headerTrailing,
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              padding,
              title == null ? padding : 16,
              padding,
              padding,
            ),
            child: child,
          ),
          if (footer != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.line)),
              ),
              child: footer,
            ),
        ],
      ),
    );
  }
}

/// Padanan `.section-heading` dengan eyebrow.
class GrowviaSectionHeading extends StatelessWidget {
  const GrowviaSectionHeading({
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _HeadRow(
        lead: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) ...[
              Text(
                eyebrow!.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.56,
                  color: t.secondary,
                ),
              ),
              const SizedBox(height: 7),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.54,
                color: t.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: t.secondary),
              ),
            ],
          ],
        ),
        trail: trailing,
      ),
    );
  }
}

/// Padanan `components/connection-notice.blade.php`.
class GrowviaConnectionNotice extends StatelessWidget {
  const GrowviaConnectionNotice({this.onTap, this.trailing, super.key});

  /// Aksi opsional, padanan tautan "Pengaturan" di komponen web.
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    final action =
        trailing ??
        (onTap == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pengaturan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.noticeInk,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GrowviaIcon('arrow', size: 14, color: t.noticeInk),
                ],
              ));
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: t.noticeSurface,
        border: Border.all(color: t.noticeLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _HeadRow(
        lead: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GrowviaIcon('info', size: 17, color: t.noticeInk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Sensornya belum nyambung. ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: t.noticeInk,
                      ),
                    ),
                    TextSpan(
                      text:
                          'Angka, grafik, dan status perangkat belum ada. '
                          'Nggak ada data bohongan di sini.',
                      style: TextStyle(color: t.noticeInk),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
        trail: action,
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      ),
    );
  }
}

/// Padanan `components/empty-chart.blade.php`.
///
/// Menampilkan kisi grafik bergaris putus-putus dengan keadaan kosong di
/// tengahnya — bentuk yang sama dengan web, bukan sekadar teks.
class GrowviaEmptyChart extends StatelessWidget {
  const GrowviaEmptyChart({
    this.title = 'Tren suhu udara',
    this.subtitle = 'Riwayat pembacaan sensor',
    this.node = 'Node1',
    this.period = '24 jam',
    this.cta,
    super.key,
  });

  final String title;
  final String subtitle;
  final String node;
  final String period;
  final Widget? cta;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return GrowviaPanel(
      title: title,
      subtitle: subtitle,
      headerTrailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(period, style: TextStyle(fontSize: 12, color: t.secondary)),
      ),
      footer: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: t.legend,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  '$node / Belum ada pembacaan',
                  style: TextStyle(fontSize: 12, color: t.secondary),
                ),
              ),
            ],
          ),
          Text(
            'Pembaruan terakhir —',
            style: TextStyle(fontSize: 12, color: t.secondary),
          ),
        ],
      ),
      // Tinggi minimum, bukan tinggi tetap: pada text scale besar isi keadaan
      // kosong tumbuh dan kotak harus ikut memanjang, bukan memotongnya.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 250),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: CustomPaint(
                  painter: _DashedGridPainter(color: t.chartGrid, lines: 5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: _EmptyState(
                icon: 'chart',
                title: 'Belum ada cerita dari sensor.',
                message:
                    'Grafik $node belum tersedia.\nIntegrasi sensor belum aktif.',
                cta: cta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.cta,
  });

  final String icon;
  final String title;
  final String message;
  final Widget? cta;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: GrowviaIcon(icon, size: 24, color: t.green)),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.32,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.7, color: t.secondary),
          ),
          if (cta != null) ...[const SizedBox(height: 10), cta!],
        ],
      ),
    );
  }
}

/// Kisi grafik bergaris putus-putus (`.chart-grid` di web).
class _DashedGridPainter extends CustomPainter {
  const _DashedGridPainter({required this.color, required this.lines});

  final Color color;
  final int lines;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 4.0;
    const gap = 5.0;
    for (var i = 0; i < lines; i++) {
      final y = size.height * i / (lines - 1);
      var x = 0.0;
      while (x < size.width) {
        final end = math.min(x + dash, size.width);
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
        x = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedGridPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.lines != lines;
}

/// Padanan `components/node-status.blade.php`.
class GrowviaNodeStatus extends StatelessWidget {
  const GrowviaNodeStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return GrowviaPanel(
      title: 'Node rumah kaca',
      subtitle: 'Dua area, satu ruang kerja.',
      headerTrailing: GrowviaIcon('connection', size: 20, color: t.muted),
      footer: Text(
        'Status koneksi belum dapat diperiksa.',
        style: TextStyle(fontSize: 12, color: t.secondary),
      ),
      child: Column(
        children: const [
          _DeviceRow(
            icon: 'sun',
            tone: 'amber',
            name: 'Node1',
            detail: 'Iklim rumah kaca',
          ),
          _DeviceRow(
            icon: 'drop',
            tone: 'blue',
            name: 'Node2',
            detail: 'Tanah & air',
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.icon,
    required this.tone,
    required this.name,
    required this.detail,
  });

  final String icon;
  final String tone;
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    // Pada text scale besar, badge turun ke baris sendiri agar tidak overflow.
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final stacked = scale > 1.4;
    final head = Row(
      children: [
        GrowviaIconTile(icon: icon, tone: tone),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: t.ink,
                ),
              ),
              Text(detail, style: TextStyle(fontSize: 12, color: t.secondary)),
            ],
          ),
        ),
        if (!stacked) ...[
          const SizedBox(width: 8),
          const GrowviaBadge('Belum aktif'),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                head,
                const SizedBox(height: 8),
                const GrowviaBadge('Belum aktif'),
              ],
            )
          : head,
    );
  }
}

/// Padanan `.pump-visual` + `.pump-ring` di web.
class GrowviaPumpVisual extends StatelessWidget {
  const GrowviaPumpVisual({super.key});

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    // Ring luar 92px + outline 7px: outline digambar sebagai border pada
    // kotak 106px yang menampung ring, sama seperti `outline` di web.
    return Center(
      child: Container(
        width: 106,
        height: 106,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: t.pumpOutline, width: 7),
        ),
        child: Center(
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: t.pumpSurface,
              shape: BoxShape.circle,
              border: Border.all(color: t.pumpLine),
            ),
            child: Center(
              child: GrowviaIcon('power', size: 34, color: t.pumpInk),
            ),
          ),
        ),
      ),
    );
  }
}

/// Padanan `components/garden-art.blade.php`.
///
/// Ilustrasi rumah kaca: sebagian jalur digambar penuh (`fill`), sebagian
/// hanya garis (`stroke`). Keduanya memakai token ilustrasi web.
class GrowviaGardenArt extends StatelessWidget {
  const GrowviaGardenArt({this.height = 240, super.key});

  final double height;

  // Jalur berisi warna (--illustration-fill).
  @visibleForTesting
  static const List<String> filledPaths = <String>['M96 60h174v143H96z'];

  // Jalur bergaris (currentColor = --illustration-ink).
  @visibleForTesting
  static const List<String> strokedPaths = <String>[
    'm52 107 100-66 128 51v123H52V107Z',
    'm152 41 36 57v117M52 107l136-9 92-6M96 78v137M143 61v154M233 74v141M52 151l136-3 92-1M39 215h257',
    'M116 201v-40m0 23c-17 0-21-11-21-11 16-2 21 11 21 11Zm0-9c0-17 15-20 15-20 3 16-15 20-15 20ZM161 201v-38m0 25c-17 0-21-11-21-11 16-2 21 11 21 11Zm0-14c0-16 15-19 15-19 2 16-15 19-15 19ZM212 202v-35m0 19c-16-1-20-12-20-12 14-3 20 12 20 12Zm0-11c2-15 16-18 16-18 2 16-16 18-16 18Z',
    'M83 202h153v12H83zM274 28v11m-17-3 6 6m20-6-6 6m18 8h-10M32 144v8m-4-4h8',
  ];

  // Lingkaran berisi warna: (cx, cy, r).
  @visibleForTesting
  static const List<(double, double, double)> filledCircles =
      <(double, double, double)>[(302, 182, 9), (35, 59, 5)];

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return AspectRatio(
      aspectRatio: 360 / 240,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height),
        child: CustomPaint(
          painter: _GardenArtPainter(
            fill: t.illustrationFill,
            ink: t.illustrationInk,
          ),
        ),
      ),
    );
  }
}

class _GardenArtPainter extends CustomPainter {
  _GardenArtPainter({required this.fill, required this.ink});

  final Color fill;
  final Color ink;

  static final List<Path> _filledCache = GrowviaGardenArt.filledPaths
      .map(parseSvgPath)
      .toList(growable: false);
  static final List<Path> _strokedCache = GrowviaGardenArt.strokedPaths
      .map(parseSvgPath)
      .toList(growable: false);

  @override
  void paint(Canvas canvas, Size size) {
    // ViewBox 360x240; pertahankan rasio agar ilustrasi tidak gepeng.
    final scale = math.min(size.width / 360, size.height / 240);
    canvas.save();
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 240 * scale) / 2,
    );
    canvas.scale(scale);

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final path in _filledCache) {
      canvas.drawPath(path, fillPaint);
    }
    for (final (cx, cy, r) in GrowviaGardenArt.filledCircles) {
      canvas.drawCircle(Offset(cx, cy), r, fillPaint);
    }

    final strokePaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    for (final path in _strokedCache) {
      canvas.drawPath(path, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GardenArtPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.ink != ink;
}

/// Padanan `.text-link` di web: tautan teks dengan ikon.
class GrowviaTextLink extends StatelessWidget {
  const GrowviaTextLink({
    required this.label,
    this.icon = 'arrow',
    this.onTap,
    super.key,
  });

  final String label;
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    final enabled = onTap != null;
    final color = enabled ? t.green : t.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GrowviaIcon(icon, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

/// Tautan berbentuk kartu: satu-satunya implementasi tile navigasi.
///
/// Dipakai untuk menu pengelolaan, profil, dan pintasan panduan. Menggantikan
/// `WorkspaceTile` lama yang menduplikasi dekorasi panel.
class GrowviaLinkTile extends StatelessWidget {
  const GrowviaLinkTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;

  /// Nama ikon Growvia, sama dengan `<x-icon name="...">` di web.
  final String icon;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              GrowviaIconTile(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: t.secondary),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                GrowviaIcon('arrow', size: 16, color: t.secondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Padanan `.node-overview` di web: ringkasan satu node.
class GrowviaNodeOverview extends StatelessWidget {
  const GrowviaNodeOverview({
    required this.node,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.tone = 'green',
    this.metrics = const <String, String>{},
    this.onTap,
    super.key,
  });

  final String node;
  final String title;
  final String subtitle;
  final String icon;
  final String tone;

  /// Pasangan label/nilai yang ditampilkan sebagai angka besar.
  final Map<String, String> metrics;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GrowviaIconTile(icon: icon, tone: tone),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.4,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: t.secondary),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    GrowviaIcon('arrow', size: 16, color: t.secondary),
                ],
              ),
              if (metrics.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final entry in metrics.entries)
                      SizedBox(
                        width: 110,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -1.2,
                                color: t.ink,
                              ),
                            ),
                            Text(
                              entry.key,
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Padanan `.definition-list` untuk pasangan label/nilai konfigurasi.
class GrowviaDefinitionList extends StatelessWidget {
  const GrowviaDefinitionList({required this.entries, super.key});

  final Map<String, String> entries;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Column(
      children: [
        for (final entry in entries.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final label = Text(
                  entry.key,
                  style: TextStyle(fontSize: 12, color: t.secondary),
                );
                final value = Text(
                  entry.value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: t.ink,
                  ),
                );
                final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
                if (constraints.maxWidth < 280 || scale > 1.6) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label,
                      const SizedBox(height: 2),
                      Align(alignment: Alignment.centerLeft, child: value),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: label),
                    const SizedBox(width: 16),
                    Flexible(child: value),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
