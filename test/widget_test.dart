import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const base = 'https://growvia.example/api/v1';

http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

MockClient loginClient({String role = 'user'}) {
  final user = {
    'id': 1,
    'name': 'Pengelola Kebun Uji',
    'email': 'kebun@example.test',
    'role': role,
    'is_active': true,
  };
  return MockClient((request) async {
    if (request.url.path.endsWith('/auth/login')) {
      return jsonResponse({'token': 'test-token', 'user': user});
    }
    if (request.url.path.endsWith('/auth/me')) {
      return jsonResponse({'user': user});
    }
    if (request.url.path.endsWith('/workspace')) {
      return jsonResponse({
        'settings': {'th_suhu_min': '25', 'th_suhu_max': '30'},
        'counts': null,
        'recent_activities': [],
        'telemetry_available': false,
      });
    }
    return jsonResponse({'data': []});
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'growvia.api_url': base});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('starts at an honest Indonesian login screen', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    expect(find.text('Masuk ke Growvia'), findsOneWidget);
    expect(find.text('Lihat pratinjau tanpa akun'), findsNothing);
    expect(find.textContaining('Tujuan API sudah diatur'), findsNothing);
    expect(find.text('Hello World!'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('login opens navigation after a valid account', (tester) async {
    final client = loginClient();
    addTearDown(client.close);
    await tester.pumpWidget(MainApp(client: client));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login-email')), 'kebun@example.test');
    await tester.enterText(find.byKey(const Key('login-password')), 'rahasia');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Belum ada pembacaan'), findsOneWidget);
    await tester.tap(find.text('Riwayat').last);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada riwayat sensor'), findsOneWidget);
    await tester.tap(find.text('Edukasi').last);
    await tester.pumpAndSettle();
    expect(find.text('Kenali kebunmu'), findsOneWidget);
    await tester.tap(find.text('Pengaturan').last);
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan perangkat ini'), findsOneWidget);
  });

  testWidgets('local settings can be saved and restored without an account', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    // Pengaturan lokal bisa diakses dari layar masuk tanpa akun.
    await tester.ensureVisible(find.text('Atur koneksi API'));
    await tester.tap(find.text('Atur koneksi API'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('api-url')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('api-url')),
      'https://growvia.example/api/v1',
    );
    await tester.ensureVisible(find.text('Simpan di perangkat'));
    await tester.tap(find.text('Simpan di perangkat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tersimpan di perangkat'), findsWidgets);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('growvia.api_url'),
      'https://growvia.example/api/v1',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Atur koneksi API'));
    await tester.tap(find.text('Atur koneksi API'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('api-url')),
    );
    expect(field.controller?.text, 'https://growvia.example/api/v1');
  });
}