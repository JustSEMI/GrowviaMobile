import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growvia_mobile/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'growvia.api_url': 'https://growvia.example/api/v1',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'a rejected API login stays on the login page with a durable error',
    (tester) async {
      final client = MockClient((_) async => http.Response('{}', 401));
      await tester.pumpWidget(MainApp(client: client));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'petani@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'wrong-password',
      );
      await tester.ensureVisible(find.text('Masuk').last);
      await tester.tap(find.text('Masuk').last);
      await tester.pumpAndSettle();

      expect(find.text('Masuk ke Growvia'), findsOneWidget);
      expect(find.textContaining('tidak sesuai'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets(
    'a successful API login loads history and logout returns to login',
    (tester) async {
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'token': 'test-token',
              'user': {
                'id': 7,
                'name': 'Petani Uji',
                'email': 'petani@example.test',
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/auth/logout')) {
          return http.Response('', 204);
        }
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 1,
                'node': 'node1',
                'metric': 'temperature',
                'value': 26.5,
                'unit': '°C',
                'recorded_at': '2026-09-16T10:00:00Z',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await tester.pumpWidget(MainApp(client: client));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'petani@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'test-password',
      );
      await tester.ensureVisible(find.text('Masuk').last);
      await tester.tap(find.text('Masuk').last);
      await tester.pumpAndSettle();

      expect(find.text('Mode pratinjau'), findsNothing);
      expect(find.textContaining('Petani Uji'), findsWidgets);
      expect(requests, contains('/api/v1/readings'));
      await tester.tap(find.text('Riwayat').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('26.5'), findsWidgets);
      expect(find.text('Belum ada riwayat sensor'), findsNothing);
      expect(find.byKey(const Key('history-chart')), findsOneWidget);
      expect(find.byKey(const Key('history-node-filter')), findsOneWidget);
      final export = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Ekspor CSV'),
      );
      expect(export.onPressed, isNotNull);
      await tester.tap(find.byTooltip('Keluar akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar').last);
      await tester.pumpAndSettle();
      expect(find.text('Masuk ke Growvia'), findsOneWidget);
      expect(requests, contains('/api/v1/auth/logout'));
      expect(
        await const FlutterSecureStorage().read(key: 'growvia.session'),
        isNull,
      );
    },
  );
}
