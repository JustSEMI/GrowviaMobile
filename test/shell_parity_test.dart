import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'growvia.api_url': ''});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('authenticated shell opens climate detail without granting access', (
    tester,
  ) async {
    const base = 'https://growvia.example/api/v1';
    SharedPreferences.setMockInitialValues({'growvia.api_url': base});
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'isolated-shell-token',
            'user': {
              'id': 1,
              'name': 'Pengelola Kebun Uji',
              'email': 'kebun@example.test',
              'role': 'user',
              'is_active': true,
            },
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/auth/me')) {
        return http.Response(
          jsonEncode({
            'user': {
              'id': 1,
              'name': 'Pengelola Kebun Uji',
              'email': 'kebun@example.test',
              'role': 'user',
              'is_active': true,
            },
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/workspace')) {
        return http.Response(
          jsonEncode({
            'settings': {'th_suhu_min': '25', 'th_suhu_max': '30'},
            'counts': null,
            'recent_activities': [],
            'telemetry_available': false,
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'data': []}),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });
    addTearDown(client.close);
    await tester.pumpWidget(MainApp(client: client));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'kebun@example.test',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'rahasia',
    );
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    final climate = find.byKey(const Key('open-climate'));
    expect(climate, findsOneWidget);
    await tester.ensureVisible(climate);
    await tester.tap(climate);
    await tester.pumpAndSettle();
    expect(find.text('Iklim rumah kaca'), findsWidgets);
    expect(find.text('Target lingkungan'), findsOneWidget);
    expect(find.text('Pengguna'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guide includes the same six learning topics as the website', (
    tester,
  ) async {
    const base = 'https://growvia.example/api/v1';
    SharedPreferences.setMockInitialValues({'growvia.api_url': base});
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({
            'token': 'isolated-shell-token',
            'user': {
              'id': 1,
              'name': 'Pengelola Kebun Uji',
              'email': 'kebun@example.test',
              'role': 'user',
              'is_active': true,
            },
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/auth/me')) {
        return http.Response(
          jsonEncode({
            'user': {
              'id': 1,
              'name': 'Pengelola Kebun Uji',
              'email': 'kebun@example.test',
              'role': 'user',
              'is_active': true,
            },
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/workspace')) {
        return http.Response(
          jsonEncode({
            'settings': {'th_suhu_min': '25', 'th_suhu_max': '30'},
            'counts': null,
            'recent_activities': [],
            'telemetry_available': false,
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'data': []}),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });
    addTearDown(client.close);
    await tester.pumpWidget(MainApp(client: client));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'kebun@example.test',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'rahasia',
    );
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edukasi').last);
    await tester.pumpAndSettle();
    for (final topic in [
      'Suhu dan ventilasi',
      'Kelembapan udara',
      'Kapan perlu menyiram?',
      'Cahaya dan CO2',
      'Tandon dan pompa',
      'Kapan menghubungi admin?',
    ]) {
      expect(find.text(topic), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  for (final role in ['admin', 'user']) {
    for (final size in [
      const Size(375, 812),
      const Size(812, 375),
      const Size(1100, 800),
    ]) {
      for (final scale in [1.0, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets(
            'authenticated $role shell at $size scale $scale dark $dark',
            (tester) async {
              const base = 'https://growvia.example/api/v1';
              SharedPreferences.setMockInitialValues({
                'growvia.api_url': base,
                'growvia.theme': dark ? 'dark' : 'light',
              });
              FlutterSecureStorage.setMockInitialValues({
                'growvia.session': jsonEncode({
                  'base_url': base,
                  'token': 'isolated-shell-token',
                }),
              });
              final calls = <String>[];
              final client = MockClient((request) async {
                calls.add(request.url.path);
                Object response;
                if (request.url.path.endsWith('/auth/me')) {
                  response = {
                    'user': {
                      'id': 1,
                      'name': 'Pengelola Kebun Uji',
                      'email': 'kebun@example.test',
                      'role': role,
                      'is_active': true,
                    },
                  };
                } else if (request.url.path.endsWith('/workspace')) {
                  response = {
                    'settings': {'th_suhu_min': '25', 'th_suhu_max': '30'},
                    'counts': role == 'admin'
                        ? {
                            'users_total': 4,
                            'users_active': 3,
                            'users_inactive': 1,
                            'admins': 1,
                          }
                        : null,
                    'recent_activities': [],
                    'telemetry_available': false,
                  };
                } else {
                  response = {'data': []};
                }
                return http.Response(
                  jsonEncode(response),
                  200,
                  headers: {'Content-Type': 'application/json'},
                );
              });
              addTearDown(client.close);
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              tester.platformDispatcher.accessibilityFeaturesTestValue =
                  const FakeAccessibilityFeatures(disableAnimations: true);
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              addTearDown(
                tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
              );
              await tester.pumpWidget(MainApp(client: client));
              await tester.pumpAndSettle();
              expect(
                calls.where((path) => path.endsWith('/workspace')),
                hasLength(1),
              );
              expect(
                find.byKey(const Key('open-users')),
                role == 'admin' ? findsOneWidget : findsNothing,
              );
              expect(find.byKey(const Key('open-account')), findsOneWidget);
              expect(tester.takeException(), isNull);
              for (final tab in ['Riwayat', 'Edukasi', 'Pengaturan']) {
                await tester.tap(find.text(tab).last);
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '$tab $role $size $scale',
                );
              }
            },
          );
        }
      }
    }
  }

  testWidgets(
    'workspace connection failure stays visible without an uncaught async error',
    (tester) async {
      const base = 'https://growvia.example/api/v1';
      SharedPreferences.setMockInitialValues({'growvia.api_url': base});
      FlutterSecureStorage.setMockInitialValues({
        'growvia.session': jsonEncode({
          'base_url': base,
          'token': 'isolated-shell-token',
        }),
      });
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 1,
                'name': 'Kebun Uji',
                'email': 'kebun@example.test',
                'role': 'user',
                'is_active': true,
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/workspace')) {
          return http.Response('{}', 503);
        }
        return http.Response('{"data":[]}', 200);
      });
      addTearDown(client.close);
      await tester.pumpWidget(MainApp(client: client));
      await tester.pumpAndSettle();
      expect(find.text('Ringkasan server belum dimuat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('password recovery is reachable from the login screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    expect(find.text('Lupa kata sandi?'), findsOneWidget);
  });
}
