import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/core/theme.dart';
import 'package:growvia_mobile/core/tokens.dart';
import 'package:growvia_mobile/ui/growvia_components.dart';
import 'package:growvia_mobile/ui/svg_path.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.dark
          ? GrowviaTheme.dark()
          : GrowviaTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );

void main() {
  group('token tema', () {
    test('light dan dark sama-sama terpasang di ThemeData', () {
      final light = GrowviaTheme.light();
      final dark = GrowviaTheme.dark();
      expect(light.extension<GrowviaTokens>(), isNotNull);
      expect(dark.extension<GrowviaTokens>(), isNotNull);
      expect(light.extension<GrowviaTokens>(), GrowviaTokens.light);
      expect(dark.extension<GrowviaTokens>(), GrowviaTokens.dark);
    });

    test('nilai token mengikuti light-dark CSS', () {
      // Beberapa nilai kunci, dibandingkan langsung dengan app.css.
      expect(GrowviaTokens.light.canvas, const Color(0xfff7f6f3));
      expect(GrowviaTokens.dark.canvas, const Color(0xff171b18));
      expect(GrowviaTokens.light.brandSurface, const Color(0xff263c2e));
      expect(GrowviaTokens.dark.brandSurface, const Color(0xff324836));
      expect(GrowviaTokens.light.navActive, const Color(0xff24492c));
      expect(GrowviaTokens.dark.navActive, const Color(0xffc9e6bb));
      expect(GrowviaTokens.light.scrim, const Color(0x6b141c16));
      expect(GrowviaTokens.dark.scrim, const Color(0xb8070b08));
    });

    test('skema Material memakai warna Growvia, bukan ungu bawaan', () {
      final scheme = GrowviaTheme.light().colorScheme;
      expect(scheme.primary, GrowviaTokens.light.green);
      expect(scheme.error, GrowviaTokens.light.red);
      expect(scheme.surface, GrowviaTokens.light.surface);
    });

    test('tone badge mengembalikan pasangan warna yang benar', () {
      const t = GrowviaTokens.light;
      expect(t.tone('blue').foreground, t.blue);
      expect(t.tone('blue').background, t.paleBlue);
      expect(t.tone('amber').background, t.paleAmber);
      expect(t.tone('red').background, t.paleRed);
      expect(t.tone('neutral').foreground, t.secondary);
      expect(t.tone('apa pun').foreground, t.green, reason: 'bawaan hijau');
    });

    test('lerp menghasilkan nilai antara', () {
      final mid = GrowviaTokens.light.lerp(GrowviaTokens.dark, 0.5);
      expect(mid.canvas, isNot(GrowviaTokens.light.canvas));
      expect(mid.canvas, isNot(GrowviaTokens.dark.canvas));
    });
  });

  group('GrowviaBadge', () {
    testWidgets('menampilkan label huruf besar', (tester) async {
      await tester.pumpWidget(_host(const GrowviaBadge('Belum aktif')));
      expect(find.text('BELUM AKTIF'), findsOneWidget);
    });

    testWidgets('titik hanya muncul bila diminta', (tester) async {
      await tester.pumpWidget(_host(const GrowviaBadge('Menunggu', dot: true)));
      final decorated = tester.widgetList<Container>(find.byType(Container));
      final hasDot = decorated.any((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.shape == BoxShape.circle;
      });
      expect(hasDot, isTrue);

      await tester.pumpWidget(_host(const GrowviaBadge('Menunggu')));
      final withoutDot = tester.widgetList<Container>(find.byType(Container));
      expect(
        withoutDot.any((c) {
          final d = c.decoration;
          return d is BoxDecoration && d.shape == BoxShape.circle;
        }),
        isFalse,
      );
    });
  });

  group('GrowviaPanel', () {
    testWidgets('judul, subjudul, dan footer dirender', (tester) async {
      await tester.pumpWidget(
        _host(
          const GrowviaPanel(
            title: 'Kontrol pompa',
            subtitle: 'Irigasi / Node2',
            footer: Text('Catatan kaki'),
            child: Text('Isi panel'),
          ),
        ),
      );
      expect(find.text('Kontrol pompa'), findsOneWidget);
      expect(find.text('Irigasi / Node2'), findsOneWidget);
      expect(find.text('Catatan kaki'), findsOneWidget);
      expect(find.text('Isi panel'), findsOneWidget);
    });

    testWidgets('tanpa judul tetap menampilkan isi', (tester) async {
      await tester.pumpWidget(_host(const GrowviaPanel(child: Text('Isi'))));
      expect(find.text('Isi'), findsOneWidget);
    });
  });

  group('GrowviaEmptyChart', () {
    testWidgets('menampilkan kisi, ikon, dan pesan kosong', (tester) async {
      await tester.pumpWidget(_host(const GrowviaEmptyChart()));
      expect(find.text('Tren suhu udara'), findsOneWidget);
      expect(find.text('24 jam'), findsOneWidget);
      expect(find.text('Belum ada cerita dari sensor.'), findsOneWidget);
      expect(find.textContaining('Node1'), findsWidgets);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('grafik kosong tidak melaporkan overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(const GrowviaEmptyChart()));
      expect(tester.takeException(), isNull);
    });
  });

  group('GrowviaNodeStatus', () {
    testWidgets('menampilkan dua node dengan badge', (tester) async {
      await tester.pumpWidget(_host(const GrowviaNodeStatus()));
      expect(find.text('Node1'), findsOneWidget);
      expect(find.text('Node2'), findsOneWidget);
      expect(find.text('Iklim rumah kaca'), findsOneWidget);
      expect(find.text('Tanah & air'), findsOneWidget);
      expect(find.text('BELUM AKTIF'), findsNWidgets(2));
    });
  });

  group('GrowviaConnectionNotice', () {
    testWidgets('menyatakan sensor belum aktif tanpa klaim palsu', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const GrowviaConnectionNotice()));
      expect(find.textContaining('Sensornya belum nyambung'), findsOneWidget);
      expect(find.textContaining('Nggak ada data bohongan'), findsOneWidget);
      expect(find.text('Pengaturan'), findsNothing);
    });

    testWidgets('tautan Pengaturan muncul dan memanggil aksi', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(GrowviaConnectionNotice(onTap: () => tapped = true)),
      );
      expect(find.text('Pengaturan'), findsOneWidget);
      await tester.tap(find.text('Pengaturan'));
      expect(tapped, isTrue);
    });
  });

  group('GrowviaPumpVisual', () {
    testWidgets('merender ring pompa tanpa overflow', (tester) async {
      await tester.pumpWidget(_host(const Center(child: GrowviaPumpVisual())));
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('GrowviaGardenArt', () {
    testWidgets('merender tanpa error pada ukuran layar HP', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(const GrowviaGardenArt()));
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    test(
      'semua jalur ilustrasi bisa diparse dan berada di viewBox 360x240',
      () {
        // Membuktikan geometri dari garden-art.blade.php benar-benar terbaca,
        // sehingga ilustrasi tergambar — bukan kotak kosong.
        final all = <String>[
          ...GrowviaGardenArt.filledPaths,
          ...GrowviaGardenArt.strokedPaths,
        ];
        expect(all, hasLength(5));
        for (final source in all) {
          final bounds = parseSvgPath(source).getBounds();
          expect(bounds.width, greaterThan(0), reason: 'jalur kosong: $source');
          expect(bounds.left, greaterThanOrEqualTo(-0.5));
          expect(bounds.top, greaterThanOrEqualTo(-0.5));
          expect(bounds.right, lessThanOrEqualTo(360.5));
          expect(bounds.bottom, lessThanOrEqualTo(240.5));
        }
      },
    );

    test('lingkaran ilustrasi berada di dalam viewBox', () {
      for (final (cx, cy, r) in GrowviaGardenArt.filledCircles) {
        expect(cx - r, greaterThanOrEqualTo(-0.5));
        expect(cy - r, greaterThanOrEqualTo(-0.5));
        expect(cx + r, lessThanOrEqualTo(360.5));
        expect(cy + r, lessThanOrEqualTo(240.5));
      }
    });
  });

  group('GrowviaDefinitionList', () {
    testWidgets('menampilkan pasangan label dan nilai', (tester) async {
      await tester.pumpWidget(
        _host(
          const GrowviaDefinitionList(
            entries: {
              'Mode pompa': 'Otomatis',
              'Ambang mulai menyiram': '< 30%',
            },
          ),
        ),
      );
      expect(find.text('Mode pompa'), findsOneWidget);
      expect(find.text('Otomatis'), findsOneWidget);
      expect(find.text('< 30%'), findsOneWidget);
    });

    testWidgets('menumpuk vertikal saat ruang sempit', (tester) async {
      tester.view.physicalSize = const Size(280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          const GrowviaDefinitionList(
            entries: {'Batas durasi pompa': '15 menit'},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
