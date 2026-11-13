import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/core/app_controller.dart';
import 'package:growvia_mobile/core/preferences.dart';
import 'package:growvia_mobile/features/settings_page.dart';
import 'package:growvia_mobile/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('default local login stays silent and sends nothing', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await tester.pumpWidget(
      MainApp(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 500);
        }),
      ),
    );
    await tester.pumpAndSettle();
    // Kartu status API dihapus dari layar masuk atas permintaan pengguna;
    // tetap dipastikan tidak ada permintaan jaringan tersembunyi di sini.
    expect(find.text('HTTP lokal · khusus debug'), findsNothing);
    expect(find.textContaining('Koneksi belum diverifikasi'), findsNothing);
    expect(find.text('Backend belum terhubung'), findsNothing);
    expect(requests, isEmpty);
  });

  testWidgets(
    'settings saves local or HTTPS endpoints without network requests',
    (tester) async {
      final requests = <http.Request>[];
      await tester.pumpWidget(
        MainApp(
          client: MockClient((request) async {
            requests.add(request);
            return http.Response('{}', 500);
          }),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Atur koneksi API'));
      await tester.tap(find.text('Atur koneksi API'));
      await tester.pumpAndSettle();
      expect(find.textContaining('USB'), findsWidgets);
      expect(find.textContaining('10.0.2.2'), findsWidgets);
      for (final url in [
        'http://127.0.0.1:8000/api/v1',
        'http://localhost:8000/api/v1',
        'http://10.0.2.2:8000/api/v1',
        'https://growvia.example/api/v1',
        '',
      ]) {
        await tester.enterText(find.byKey(const Key('api-url')), url);
        await tester.ensureVisible(find.text('Simpan di perangkat'));
        await tester.tap(find.text('Simpan di perangkat'));
        await tester.pumpAndSettle();
        expect(
          (await SharedPreferences.getInstance()).getString('growvia.api_url'),
          url,
        );
        expect(find.textContaining('Koneksi belum diverifikasi'), findsWidgets);
        expect(requests, isEmpty);
      }
    },
  );

  testWidgets('settings uses the same strict policy as the API client', (
    tester,
  ) async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(preferences: preferences)),
      ),
    );
    for (final url in [
      'http://public.example/api/v1',
      'http://localhost.evil.test/api/v1',
      'http://user:password@localhost/api/v1',
      'https://server.test/api/../v1',
      'https://server.test/api?token=secret',
      'https://server.test/api#fragment',
    ]) {
      await tester.enterText(find.byKey(const Key('api-url')), url);
      await tester.ensureVisible(find.text('Simpan di perangkat'));
      await tester.tap(find.text('Simpan di perangkat'));
      await tester.pumpAndSettle();
      expect(
        find.text(preferences.endpointPolicy.validationMessage),
        findsOneWidget,
      );
      expect(
        (await SharedPreferences.getInstance()).containsKey('growvia.api_url'),
        isFalse,
      );
    }
  });

  testWidgets('production-policy settings reject local HTTP and accept HTTPS', (
    tester,
  ) async {
    final preferences = AppPreferences(allowDebugHttp: false);
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(preferences: preferences)),
      ),
    );
    expect(find.textContaining('USB'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('api-url')),
      'http://localhost:8000/api/v1',
    );
    await tester.ensureVisible(find.text('Simpan di perangkat'));
    await tester.tap(find.text('Simpan di perangkat'));
    await tester.pumpAndSettle();
    expect(
      find.text(preferences.endpointPolicy.validationMessage),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('api-url')),
      'https://growvia.example/api/v1',
    );
    await tester.ensureVisible(find.text('Simpan di perangkat'));
    await tester.tap(find.text('Simpan di perangkat'));
    await tester.pumpAndSettle();
    expect(preferences.apiUrl, 'https://growvia.example/api/v1');
  });

  testWidgets(
    'local Sanctum login shows authenticated empty telemetry, not preview',
    (tester) async {
      final paths = <String>[];
      await tester.pumpWidget(
        MainApp(
          client: MockClient((request) async {
            paths.add(request.url.path);
            expect(request.url.origin, 'http://127.0.0.1:8000');
            expect(request.followRedirects, isFalse);
            if (request.url.path == '/api/v1/auth/login') {
              expect(jsonDecode(request.body), {
                'email': 'petani@example.test',
                'password': ' test-password ',
                'device_name': 'Growvia Mobile',
              });
              return http.Response(
                jsonEncode({
                  'token': '7|sanctum-test-token',
                  'user': {
                    'id': 7,
                    'name': 'Petani Uji',
                    'email': 'petani@example.test',
                    'role': 'user',
                    'is_active': true,
                  },
                }),
                200,
              );
            }
            expect(
              request.headers['Authorization'],
              'Bearer 7|sanctum-test-token',
            );
            if (request.url.path == '/api/v1/auth/logout') {
              return http.Response('', 204);
            }
            if (request.url.path == '/api/v1/workspace') {
              return http.Response(
                jsonEncode({
                  'settings': <String, String>{},
                  'counts': null,
                  'recent_activities': [],
                  'telemetry_available': false,
                }),
                200,
              );
            }
            expect(request.url.path, '/api/v1/readings');
            return http.Response(
              jsonEncode({
                'data': [],
                'meta': {'available': false, 'reason': 'telemetry_deferred'},
              }),
              200,
            );
          }),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'petani@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        ' test-password ',
      );
      await tester.ensureVisible(find.text('Masuk').last);
      await tester.tap(find.text('Masuk').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Halo, Petani Uji'), findsOneWidget);
      expect(find.text('Mode pratinjau'), findsNothing);
      expect(find.text('Belum ada pembacaan'), findsOneWidget);
      expect(
        find.textContaining('Telemetri sensor belum diaktifkan'),
        findsOneWidget,
      );
      final stored = jsonDecode(
        (await const FlutterSecureStorage().read(key: 'growvia.session'))!,
      );
      expect(stored, {
        'base_url': 'http://127.0.0.1:8000/api/v1',
        'token': '7|sanctum-test-token',
      });
      expect(stored.toString(), isNot(contains('test-password')));
      await tester.tap(find.byTooltip('Keluar akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar').last);
      await tester.pumpAndSettle();
      expect(paths, [
        '/api/v1/auth/login',
        '/api/v1/readings',
        '/api/v1/workspace',
        '/api/v1/auth/logout',
      ]);
      expect(
        await const FlutterSecureStorage().read(key: 'growvia.session'),
        isNull,
      );
    },
  );

  test('a saved Sanctum token restores only after local auth/me', () async {
    FlutterSecureStorage.setMockInitialValues({
      'growvia.session': jsonEncode({
        'base_url': 'http://127.0.0.1:8000/api/v1',
        'token': '7|saved-sanctum-token',
      }),
    });
    final paths = <String>[];
    final app = AppController(
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.url.origin, 'http://127.0.0.1:8000');
        expect(
          request.headers['Authorization'],
          'Bearer 7|saved-sanctum-token',
        );
        if (request.url.path == '/api/v1/auth/me') {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 7,
                'name': 'Petani Uji',
                'email': 'petani@example.test',
                'role': 'user',
                'is_active': true,
              },
            }),
            200,
          );
        }
        return http.Response(
          '{"data":[],"meta":{"available":false,"reason":"telemetry_deferred"}}',
          200,
        );
      }),
    );
    addTearDown(app.dispose);
    await app.initialize();
    expect(app.session?.userId, 7);
    expect(app.readings, isEmpty);
    expect(app.dataError, isNull);
    expect(paths, ['/api/v1/auth/me', '/api/v1/readings']);
  });

  test('switching to the debug default never migrates a token from another endpoint', () async {
    FlutterSecureStorage.setMockInitialValues({
      'growvia.session': jsonEncode({
        'base_url': 'https://growvia.example/api/v1',
        'token': 'old-token',
      }),
    });
    var calls = 0;
    final app = AppController(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
    addTearDown(app.dispose);
    await app.initialize();
    expect(app.session, isNull);
    expect(calls, 0);
    expect(
      await const FlutterSecureStorage().read(key: 'growvia.session'),
      isNull,
    );
  });
}
