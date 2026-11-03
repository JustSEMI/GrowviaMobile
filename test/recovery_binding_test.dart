import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growvia_mobile/core/app_controller.dart';
import 'package:growvia_mobile/data/api_client.dart';
import 'package:growvia_mobile/features/recovery_page.dart';

import 'management_pages_test.dart' show mount, enter, tap, reveal;

void main() {
  final token = List.filled(64, 'A').join();
  String link(String origin) => '$origin/reset-sandi/$token?email=a%40b.test';
  const base = 'https://api.example.test/api/v1';

  test('recovery origin is exact and raw unsafe paths are rejected', () {
    for (final origin in [
      'https://other.test',
      'https://web.example.test',
      'http://api.example.test',
      'https://api.example.test:444',
      'https://api.example.test.evil.test',
      'https://@api.example.test',
      'https://user@api.example.test',
      'https://api%2eexample.test',
      'https://api.example.test/../',
      'https://api.example.test/%2e%2e',
      'https://api.example.test/a/..',
    ]) {
      expect(
        parseRecoveryLink(link(origin), baseUrl: base),
        isNull,
        reason: origin,
      );
    }
    for (final suffix in [
      '#fragment',
      '&email=c%40d.test',
      '&next=https://evil.test',
    ]) {
      expect(
        parseRecoveryLink(
          '${link('https://api.example.test')}$suffix',
          baseUrl: base,
        ),
        isNull,
      );
    }
    final parsed = parseRecoveryLink(
      link('https://api.example.test:443'),
      baseUrl: base,
    );
    expect(parsed?.token, token);
    expect(parsed?.email, 'a@b.test');
    expect(
      parseRecoveryLink(link('https://api.example.test'), baseUrl: ''),
      isNull,
    );
  });

  test(
    'loopback aliases require debug permission identical scheme and port',
    () {
      for (final host in ['localhost', '127.0.0.1', '10.0.2.2']) {
        expect(
          parseRecoveryLink(
            link('http://$host:8000'),
            baseUrl: 'http://localhost:8000/api/v1',
          ),
          isNotNull,
        );
        expect(
          parseRecoveryLink(
            link('https://$host:8000'),
            baseUrl: 'https://localhost:8000/api/v1',
            allowDebugAliases: false,
          ),
          host == 'localhost' ? isNotNull : isNull,
        );
        expect(
          parseRecoveryLink(
            link('http://$host:8001'),
            baseUrl: 'http://localhost:8000/api/v1',
          ),
          isNull,
        );
        expect(
          parseRecoveryLink(
            link('http://$host:8000'),
            baseUrl: 'https://localhost:8000/api/v1',
          ),
          isNull,
        );
      }
    },
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({'growvia.api_url': base});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'controller expected endpoint guard refuses changed origin or API path',
    () async {
      final requests = <http.Request>[];
      final app = AppController(
        client: MockClient((r) async {
          requests.add(r);
          return http.Response('{"message":"done"}', 200);
        }),
      );
      await app.initialize();
      for (final changed in [
        'https://other.test/api/v1',
        'https://api.example.test/other/api/v1',
      ]) {
        app.preferences.apiUrl = changed;
        await expectLater(
          app.resetPassword(
            email: 'a@b.test',
            token: token,
            password: 'password123',
            confirmation: 'password123',
            expectedBaseUrl: base,
          ),
          throwsA(isA<ApiException>()),
        );
      }
      expect(requests, isEmpty);
      app.preferences.apiUrl = base;
      await app.resetPassword(
        email: 'a@b.test',
        token: token,
        password: 'password123',
        confirmation: 'password123',
        expectedBaseUrl: base,
      );
      expect(requests.single.url.toString(), '$base/auth/reset-password');
      app.dispose();
    },
  );

  for (final change in [
    'edit',
    'replacement',
    'preference',
    'silent',
    'foreign',
  ]) {
    testWidgets(
      'recovery binding invalidates $change without credential disclosure',
      (tester) async {
        final requests = <http.Request>[];
        final app = AppController(
          client: MockClient((r) async {
            requests.add(r);
            return http.Response(jsonEncode({'message': 'done'}), 200);
          }),
        );
        await app.initialize();
        await mount(tester, RecoveryPage(controller: app));
        await enter(
          tester,
          'recovery-link',
          link(
            change == 'foreign'
                ? 'https://other.test'
                : 'https://api.example.test',
          ),
        );
        await tap(tester, 'recovery-parse');
        expect(requests, isEmpty);
        await enter(tester, 'recovery-password', 'password123');
        await enter(tester, 'recovery-confirmation', 'password123');
        if (change == 'edit') {
          await enter(tester, 'recovery-link', 'invalid replacement');
        } else if (change == 'replacement') {
          await enter(
            tester,
            'recovery-link',
            link('https://api.example.test')
                .replaceFirst('a%40b.test', 'next%40b.test'),
          );
        } else if (change == 'preference') {
          await app.preferences.save(
            'https://other.test/api/v1',
            ThemeMode.light,
          );
          await app.preferences.save(base, ThemeMode.light);
          await tester.pumpAndSettle();
        } else if (change == 'silent') {
          app.preferences.apiUrl = 'https://other.test/api/v1';
        }
        if (change != 'silent') {
          await reveal(tester, find.byKey(const Key('recovery-reset')));
          expect(
            tester
                .widget<FilledButton>(find.byKey(const Key('recovery-reset')))
                .onPressed,
            isNull,
          );
        }
        await tap(tester, 'recovery-reset');
        expect(requests, isEmpty);
        await reveal(tester, find.byKey(const Key('recovery-email')));
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('recovery-email')))
              .controller!
              .text,
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox());
        app.dispose();
      },
    );
  }
}
