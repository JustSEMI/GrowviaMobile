import 'package:flutter/material.dart';

import 'growvia_icons.dart';
import 'svg_path.dart';

/// Ikon Growvia, digambar dari geometri yang sama dengan web.
///
/// Web memakai `resources/views/components/icon.blade.php` (SVG `fill`,
/// viewBox 24x24). Widget ini merender jalur yang sama lewat [CustomPaint],
/// sehingga bentuk ikon di mobile identik dengan web, bukan ikon Material.
class GrowviaIcon extends StatelessWidget {
  const GrowviaIcon(
    this.name, {
    this.size = 20,
    this.color,
    this.semanticLabel,
    super.key,
  });

  /// Nama ikon, sama dengan `<x-icon name="...">` di Blade.
  final String name;

  /// Sisi kotak ikon; mengikuti aturan `.icon` di web (20px bawaan).
  final double size;

  /// Warna; bila null memakai `IconTheme` di sekitarnya.
  final Color? color;

  /// Label aksesibilitas. Bila null, ikon dianggap dekoratif.
  final String? semanticLabel;

  /// Nama ikon yang tersedia, untuk validasi dan test.
  static Iterable<String> get availableNames => growviaIconPaths.keys;

  /// Cek ketersediaan nama tanpa membangun widget.
  static bool has(String name) => growviaIconPaths.containsKey(name);

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ?? IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color;
    final path = _IconPathCache.pathFor(name);

    Widget painter = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GrowviaIconPainter(
          path: path,
          color: resolved ?? const Color(0xff000000),
        ),
        isComplex: false,
      ),
    );

    if (semanticLabel != null) {
      painter = Semantics(label: semanticLabel, child: painter);
    } else {
      painter = ExcludeSemantics(child: painter);
    }
    return painter;
  }
}

/// Cache [Path] per nama ikon.
///
/// `Path` bersifat immutable setelah dibangun dan dipakai read-only oleh
/// painter, jadi satu instance aman dipakai bersama banyak widget.
abstract final class _IconPathCache {
  static final Map<String, Path> _cache = <String, Path>{};

  static Path pathFor(String name) => _cache.putIfAbsent(name, () {
    final source = growviaIconPaths[name];
    if (source == null) {
      throw ArgumentError.value(
        name,
        'name',
        'Ikon tidak dikenal. Tersedia: ${growviaIconPaths.keys.join(', ')}',
      );
    }
    return parseSvgPath(source);
  });

  /// Dipakai test untuk memastikan setiap ikon bisa diparse.
  static void clear() => _cache.clear();
}

/// Membangun semua ikon sekali agar galat parse muncul di test, bukan di UI.
@visibleForTesting
void warmUpIconCache() {
  _IconPathCache.clear();
  for (final name in growviaIconPaths.keys) {
    _IconPathCache.pathFor(name);
  }
}

class _GrowviaIconPainter extends CustomPainter {
  const _GrowviaIconPainter({required this.path, required this.color});

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // ViewBox sumber 24x24; skala agar pas ke sisi yang diminta.
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GrowviaIconPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.color != color;
}
