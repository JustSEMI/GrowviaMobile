import 'dart:math' as math;
import 'dart:ui';

/// Parser SVG path minimal untuk viewBox 24x24 milik Growvia.
///
/// Mendukung M L H V C S Q T A Z dalam bentuk absolut maupun relatif.
/// Tujuannya: ikon mobile memakai string `d` yang **identik** dengan
/// `resources/views/components/icon.blade.php`, bukan ikon Material.
/// Busur (`A`) dikonversi ke kurva Bezier kubik karena Flutter tidak
/// menyediakan `Path.parse`.
Path parseSvgPath(String source) => _SvgPathBuilder(source).build();

const String _commandLetters = 'MmLlHhVvCcSsQqTtAaZz';

class _SvgPathBuilder {
  _SvgPathBuilder(this.source);

  final String source;
  final Path path = Path();

  int index = 0;
  double x = 0;
  double y = 0;
  double startX = 0;
  double startY = 0;

  /// Titik kontrol terakhir untuk perintah S (kurva kubik halus).
  double? cubicX;
  double? cubicY;

  /// Titik kontrol terakhir untuk perintah T (kurva kuadratik halus).
  double? quadX;
  double? quadY;

  String command = '';

  Path build() {
    while (true) {
      _skipSeparators();
      if (index >= source.length) break;

      if (_isCommand(source[index])) {
        command = source[index];
        index++;
      } else if (command.isEmpty) {
        throw FormatException('Path tidak diawali perintah: $source');
      } else if (command == 'M') {
        // Angka setelah M tanpa huruf baru berarti lineto.
        command = 'L';
      } else if (command == 'm') {
        command = 'l';
      }

      _run(command);

      _skipSeparators();
      if (index >= source.length) break;
      if (_isCommand(source[index])) continue;
      if (!_startsNumber(source[index])) {
        throw FormatException(
          'Token tak dikenal "${source[index]}" pada posisi $index: $source',
        );
      }
      // Angka lagi: ulangi perintah yang sama (bentuk implisit SVG).
    }
    return path;
  }

  void _run(String cmd) {
    final relative = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        final nx = _number();
        final ny = _number();
        x = relative ? x + nx : nx;
        y = relative ? y + ny : ny;
        startX = x;
        startY = y;
        path.moveTo(x, y);
        _clearControls();
      case 'L':
        final nx = _number();
        final ny = _number();
        x = relative ? x + nx : nx;
        y = relative ? y + ny : ny;
        path.lineTo(x, y);
        _clearControls();
      case 'H':
        final nx = _number();
        x = relative ? x + nx : nx;
        path.lineTo(x, y);
        _clearControls();
      case 'V':
        final ny = _number();
        y = relative ? y + ny : ny;
        path.lineTo(x, y);
        _clearControls();
      case 'C':
        final x1 = _number();
        final y1 = _number();
        final x2 = _number();
        final y2 = _number();
        final nx = _number();
        final ny = _number();
        final c1x = relative ? x + x1 : x1;
        final c1y = relative ? y + y1 : y1;
        final c2x = relative ? x + x2 : x2;
        final c2y = relative ? y + y2 : y2;
        x = relative ? x + nx : nx;
        y = relative ? y + ny : ny;
        path.cubicTo(c1x, c1y, c2x, c2y, x, y);
        cubicX = c2x;
        cubicY = c2y;
        quadX = null;
        quadY = null;
      case 'S':
        final x2 = _number();
        final y2 = _number();
        final nx = _number();
        final ny = _number();
        final c1x = cubicX == null ? x : 2 * x - cubicX!;
        final c1y = cubicY == null ? y : 2 * y - cubicY!;
        final c2x = relative ? x + x2 : x2;
        final c2y = relative ? y + y2 : y2;
        x = relative ? x + nx : nx;
        y = relative ? y + ny : ny;
        path.cubicTo(c1x, c1y, c2x, c2y, x, y);
        cubicX = c2x;
        cubicY = c2y;
        quadX = null;
        quadY = null;
      case 'Q':
        final x1 = _number();
        final y1 = _number();
        final nx = _number();
        final ny = _number();
        final c1x = relative ? x + x1 : x1;
        final c1y = relative ? y + y1 : y1;
        x = relative ? x + nx : nx;
        y = relative ? y + ny : ny;
        path.quadraticBezierTo(c1x, c1y, x, y);
        quadX = c1x;
        quadY = c1y;
        cubicX = null;
        cubicY = null;
      case 'T':
        final nx = _number();
        final ny = _number();
        final c1x = quadX == null ? x : 2 * x - quadX!;
        final c1y = quadY == null ? y : 2 * y - quadY!;
        x = relative ? x + nx : nx;
        y = relative ? y + ny : ny;
        path.quadraticBezierTo(c1x, c1y, x, y);
        quadX = c1x;
        quadY = c1y;
        cubicX = null;
        cubicY = null;
      case 'A':
        final rx = _number();
        final ry = _number();
        final rotation = _number();
        final largeArc = _flag();
        final sweep = _flag();
        final nx = _number();
        final ny = _number();
        final toX = relative ? x + nx : nx;
        final toY = relative ? y + ny : ny;
        _arcTo(rx, ry, rotation, largeArc, sweep, toX, toY);
        _clearControls();
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        _clearControls();
      default:
        throw FormatException('Perintah tidak didukung: $cmd');
    }
  }

  /// Konversi busur SVG ke kurva Bezier kubik (parameterisasi endpoint).
  void _arcTo(
    double rx,
    double ry,
    double rotation,
    bool largeArc,
    bool sweep,
    double toX,
    double toY,
  ) {
    final fromX = x;
    final fromY = y;

    if (rx == 0 || ry == 0 || (fromX == toX && fromY == toY)) {
      path.lineTo(toX, toY);
      x = toX;
      y = toY;
      return;
    }

    rx = rx.abs();
    ry = ry.abs();

    final phi = rotation * math.pi / 180.0;
    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);

    final dx = (fromX - toX) / 2.0;
    final dy = (fromY - toY) / 2.0;
    final x1 = cosPhi * dx + sinPhi * dy;
    final y1 = -sinPhi * dx + cosPhi * dy;

    var rx2 = rx * rx;
    var ry2 = ry * ry;
    final x1Sq = x1 * x1;
    final y1Sq = y1 * y1;

    // Perbesar radius bila terlalu kecil untuk menjangkau kedua titik.
    final lambda = x1Sq / rx2 + y1Sq / ry2;
    if (lambda > 1) {
      final scale = math.sqrt(lambda);
      rx *= scale;
      ry *= scale;
      rx2 = rx * rx;
      ry2 = ry * ry;
    }

    var numerator = rx2 * ry2 - rx2 * y1Sq - ry2 * x1Sq;
    if (numerator < 0) numerator = 0;
    final denominator = rx2 * y1Sq + ry2 * x1Sq;
    var coefficient = denominator == 0
        ? 0.0
        : math.sqrt(numerator / denominator);
    if (largeArc == sweep) coefficient = -coefficient;

    final centerXp = coefficient * rx * y1 / ry;
    final centerYp = -coefficient * ry * x1 / rx;
    final centerX = cosPhi * centerXp - sinPhi * centerYp + (fromX + toX) / 2.0;
    final centerY = sinPhi * centerXp + cosPhi * centerYp + (fromY + toY) / 2.0;

    final startAngle = _angleBetween(
      1,
      0,
      (x1 - centerXp) / rx,
      (y1 - centerYp) / ry,
    );
    var sweepAngle = _angleBetween(
      (x1 - centerXp) / rx,
      (y1 - centerYp) / ry,
      (-x1 - centerXp) / rx,
      (-y1 - centerYp) / ry,
    );
    if (!sweep && sweepAngle > 0) sweepAngle -= 2 * math.pi;
    if (sweep && sweepAngle < 0) sweepAngle += 2 * math.pi;

    // Pecah jadi potongan <= 90 derajat agar hampiran Bezier akurat.
    final segments = math.max(1, (sweepAngle.abs() / (math.pi / 2)).ceil());
    final delta = sweepAngle / segments;
    final handle = 4.0 / 3.0 * math.tan(delta / 4.0);

    var angle = startAngle;
    for (var i = 0; i < segments; i++) {
      final next = angle + delta;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final cosB = math.cos(next);
      final sinB = math.sin(next);

      final segmentStartX = cosPhi * rx * cosA - sinPhi * ry * sinA + centerX;
      final segmentStartY = sinPhi * rx * cosA + cosPhi * ry * sinA + centerY;
      final segmentEndX = cosPhi * rx * cosB - sinPhi * ry * sinB + centerX;
      final segmentEndY = sinPhi * rx * cosB + cosPhi * ry * sinB + centerY;

      final control1X =
          segmentStartX + handle * (cosPhi * -rx * sinA - sinPhi * ry * cosA);
      final control1Y =
          segmentStartY + handle * (sinPhi * -rx * sinA + cosPhi * ry * cosA);
      final control2X =
          segmentEndX - handle * (cosPhi * -rx * sinB - sinPhi * ry * cosB);
      final control2Y =
          segmentEndY - handle * (sinPhi * -rx * sinB + cosPhi * ry * cosB);

      path.cubicTo(control1X, control1Y, control2X, control2Y, segmentEndX,
          segmentEndY);
      angle = next;
    }

    x = toX;
    y = toY;
  }

  double _angleBetween(double ux, double uy, double vx, double vy) {
    final dot = ux * vx + uy * vy;
    final lengths = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy));
    if (lengths == 0) return 0;
    var angle = math.acos((dot / lengths).clamp(-1.0, 1.0));
    if (ux * vy - uy * vx < 0) angle = -angle;
    return angle;
  }

  void _clearControls() {
    cubicX = null;
    cubicY = null;
    quadX = null;
    quadY = null;
  }

  bool _isCommand(String c) => _commandLetters.contains(c);

  bool _startsNumber(String c) =>
      _isDigit(c) || c == '+' || c == '-' || c == '.';

  bool _isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

  void _skipSeparators() {
    while (index < source.length) {
      final c = source[index];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == ',') {
        index++;
      } else {
        break;
      }
    }
  }

  double _number() {
    _skipSeparators();
    final start = index;
    if (index < source.length && (source[index] == '+' || source[index] == '-')) {
      index++;
    }
    while (index < source.length && _isDigit(source[index])) {
      index++;
    }
    if (index < source.length && source[index] == '.') {
      index++;
      while (index < source.length && _isDigit(source[index])) {
        index++;
      }
    }
    // Notasi ilmiah, misal 1e-5.
    if (index < source.length && (source[index] == 'e' || source[index] == 'E')) {
      final save = index;
      index++;
      if (index < source.length &&
          (source[index] == '+' || source[index] == '-')) {
        index++;
      }
      if (index < source.length && _isDigit(source[index])) {
        while (index < source.length && _isDigit(source[index])) {
          index++;
        }
      } else {
        index = save;
      }
    }
    if (start == index) {
      throw FormatException('Angka tidak valid pada posisi $index: $source');
    }
    return double.parse(source.substring(start, index));
  }

  /// Flag busur ditulis satu karakter dan boleh menempel tanpa pemisah.
  bool _flag() {
    _skipSeparators();
    if (index >= source.length) {
      throw FormatException('Flag busur hilang pada posisi $index: $source');
    }
    final c = source[index];
    if (c == '0') {
      index++;
      return false;
    }
    if (c == '1') {
      index++;
      return true;
    }
    throw FormatException('Flag busur tidak valid "$c" pada posisi $index');
  }
}
