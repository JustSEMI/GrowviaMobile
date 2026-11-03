import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/ui/growvia_icon.dart';
import 'package:growvia_mobile/ui/growvia_icons.dart';
import 'package:growvia_mobile/ui/svg_path.dart';

void main() {
  group('parser SVG', () {
    test('menangani perintah absolut dan relatif', () {
      final path = parseSvgPath('M2 2h20v20H2Z');
      final bounds = path.getBounds();
      expect(bounds.left, closeTo(2, 0.001));
      expect(bounds.top, closeTo(2, 0.001));
      expect(bounds.right, closeTo(22, 0.001));
      expect(bounds.bottom, closeTo(22, 0.001));
    });

    test('menangani kurva halus S dan T', () {
      final cubic = parseSvgPath('M2 12C6 2 10 22 14 12S20 2 22 12');
      expect(cubic.getBounds().width, greaterThan(0));
      final quad = parseSvgPath('M2 12Q6 2 10 12T18 12');
      expect(quad.getBounds().width, greaterThan(0));
    });

    test('menangani busur A dengan dua flag menempel', () {
      // Lingkaran penuh lewat dua busur, seperti konversi <circle>.
      final path = parseSvgPath('M4 12a8 8 0 1 0 16 0a8 8 0 1 0-16 0Z');
      final bounds = path.getBounds();
      expect(bounds.width, closeTo(16, 0.05), reason: 'diameter horizontal');
      expect(bounds.height, closeTo(16, 0.05), reason: 'diameter vertikal');
      expect(bounds.left, closeTo(4, 0.05));
      expect(bounds.top, closeTo(4, 0.05));
    });

    test('busur menerima flag tanpa pemisah spasi (a1 1 0 011 1)', () {
      // Bentuk ringkas ini muncul di hasil konversi rect bersudut.
      final path = parseSvgPath('M4 3h14a1 1 0 011 1v16a1 1 0 01-1 1H4a1 1 0 01-1-1V4a1 1 0 011-1Z');
      final bounds = path.getBounds();
      expect(bounds.left, closeTo(3, 0.05));
      expect(bounds.right, closeTo(19, 0.05));
    });

    test('menolak perintah tak dikenal', () {
      expect(() => parseSvgPath('M2 2X5 5'), throwsA(isA<FormatException>()));
    });

    test('menolak path yang tidak diawali perintah', () {
      expect(() => parseSvgPath('5 5'), throwsA(isA<FormatException>()));
    });
  });

  group('ikon Growvia', () {
    test('minimal 29 ikon tersedia', () {
      expect(growviaIconPaths.length, greaterThanOrEqualTo(29));
    });

    test('setiap ikon bisa diparse dan berada dalam viewBox 24x24', () {
      warmUpIconCache();
      final offenders = <String, Rect>{};
      for (final entry in growviaIconPaths.entries) {
        final bounds = parseSvgPath(entry.value).getBounds();
        final inside = bounds.left >= -0.5 &&
            bounds.top >= -0.5 &&
            bounds.right <= 24.5 &&
            bounds.bottom <= 24.5;
        final visible = bounds.width > 0 && bounds.height > 0;
        if (!inside || !visible) {
          offenders[entry.key] = bounds;
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'ikon di luar viewBox atau kosong: $offenders',
      );
    });

    test('nama ikon cocok dengan yang dipakai web', () {
      // Daftar ini diambil dari <x-icon name="..."> di resources/views.
      const usedInWeb = <String>[
        'arrow',
        'shield',
        'sun',
        'drop',
        'power',
        'leaf',
        'info',
        'clock',
        'users',
        'display',
        'connection',
        'chart',
        'trash',
        'settings',
        'refresh',
        'plus',
        'logout',
        'edit',
        'check',
        'arrow-up',
        'moon',
        'menu',
        'grid',
        'eye',
        'close',
        'book',
        'thermometer',
        'tank',
        'chevron-down',
      ];
      final missing = usedInWeb.where((n) => !GrowviaIcon.has(n)).toList();
      expect(missing, isEmpty, reason: 'ikon web belum tersedia: $missing');
    });

    testWidgets('merender ikon pada ukuran dan warna yang diminta', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GrowviaIcon('leaf', size: 32, color: Color(0xff346538)),
            ),
          ),
        ),
      );
      final box = tester.getSize(find.byType(GrowviaIcon));
      expect(box, const Size(32, 32));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ikon dekoratif tidak mengumumkan apa pun ke pembaca layar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GrowviaIcon('leaf')),
        ),
      );
      // Tanpa semanticLabel, ikon harus dibungkus ExcludeSemantics.
      expect(find.byType(ExcludeSemantics), findsWidgets);
      handle.dispose();
    });

    testWidgets('ikon berlabel mengumumkan labelnya', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GrowviaIcon('shield', semanticLabel: 'Keamanan'),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Keamanan'), findsOneWidget);
      handle.dispose();
    });

    test('nama tidak dikenal melempar ArgumentError yang informatif', () {
      expect(
        () => GrowviaIcon.has('tidak-ada'),
        returnsNormally,
      );
      expect(GrowviaIcon.has('tidak-ada'), isFalse);
    });
  });
}
