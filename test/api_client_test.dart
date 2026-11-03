import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:growvia_mobile/data/api_client.dart';

void main() {
  test(
    'health validates Growvia v1 without sending account credentials',
    () async {
      final api = GrowviaApi(
        baseUrl: 'http://127.0.0.1:8000/api/v1',
        client: MockClient((request) async {
          expect(request.url.toString(), 'http://127.0.0.1:8000/api/v1/health');
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], isNull);
          expect(request.body, isEmpty);
          expect(request.followRedirects, isFalse);
          return http.Response(
            '{"app":"Growvia","api_version":"v1","status":"ok"}',
            200,
          );
        }),
      );
      addTearDown(api.close);
      await api.health();
    },
  );

  test('health rejects unrelated or incompatible servers', () async {
    for (final body in [
      '{}',
      '{"app":"Other","api_version":"v1","status":"ok"}',
      '{"app":"Growvia","api_version":"v2","status":"ok"}',
      '{"app":"Growvia","api_version":"v1","status":"down"}',
    ]) {
      final api = GrowviaApi(
        baseUrl: 'http://localhost:8000/api/v1',
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(api.close);
      await expectLater(api.health(), throwsA(isA<ApiException>()));
    }
  });

  test(
    'login uses JSON, preserves password whitespace and requires a real token',
    () async {
      final api = GrowviaApi(
        baseUrl: 'https://growvia.example/api/v1',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://growvia.example/api/v1/auth/login',
          );
          expect(request.method, 'POST');
          expect(request.headers['Accept'], 'application/json');
          expect(jsonDecode(request.body)['password'], ' space preserved ');
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
        }),
      );
      final session = await api.login(
        'petani@example.test',
        ' space preserved ',
      );
      expect(session.name, 'Petani Uji');
      expect(session.token, 'test-token');
    },
  );

  test('history sends the bearer token and parses real readings', () async {
    final api = GrowviaApi(
      baseUrl: 'https://growvia.example/api/v1',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/readings');
        expect(request.url.queryParameters['node'], 'node1');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 8,
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
      }),
    );
    final records = await api.readings('test-token', node: 'node1');
    expect(records.single.value, 26.5);
    expect(records.single.unit, '°C');
    expect(records.single.recordedAt.isUtc, isTrue);
  });

  test('logout revokes the current API token and accepts 204', () async {
    final api = GrowviaApi(
      baseUrl: 'https://growvia.example/api/v1',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/logout');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.followRedirects, isFalse);
        return http.Response('', 204);
      }),
    );
    await api.logout('test-token');
  });

  for (final code in [401, 403, 404, 422, 429, 500]) {
    test('HTTP $code never becomes a successful login', () async {
      final api = GrowviaApi(
        baseUrl: 'https://growvia.example/api/v1',
        client: MockClient(
          (_) async => http.Response('private server details', code),
        ),
      );
      await expectLater(
        api.login('petani@example.test', 'not-a-real-password'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            isNot(contains('private server details')),
          ),
        ),
      );
    });
  }

  test(
    'HTML redirects and a response without a token never grant a session',
    () async {
      for (final response in [
        http.Response('<html>Login</html>', 200),
        http.Response('{}', 200),
        http.Response('', 302),
      ]) {
        final api = GrowviaApi(
          baseUrl: 'https://growvia.example/api/v1',
          client: MockClient((_) async => response),
        );
        await expectLater(
          api.login('petani@example.test', 'not-a-real-password'),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );

  test('insecure or credential-bearing URLs cannot receive credentials', () {
    for (final url in [
      'http://server.test/api',
      'https://user:password@server.test/api',
      'https://server.test/api?token=secret',
      'https://server.test/api#frag',
    ]) {
      expect(() => GrowviaApi(baseUrl: url), throwsA(isA<ApiException>()));
    }
  });
}
