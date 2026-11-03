import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:growvia_mobile/data/api_client.dart';

const user = {
  'id': 7,
  'name': 'A',
  'email': 'a@example.test',
  'role': 'admin',
  'is_active': true,
};
Map<String, dynamic> page([List<dynamic> data = const []]) => {
  'data': data,
  'meta': {
    'current_page': 1,
    'last_page': 1,
    'per_page': 15,
    'total': data.length,
  },
};
void main() {
  test(
    'HTTP errors preserve actual status without exposing raw server details',
    () async {
      for (final status in [401, 403, 404, 405, 422, 429, 500, 503, 302]) {
        final api = GrowviaApi(
          baseUrl: 'https://example.test/api/v1',
          client: MockClient(
            (_) async => http.Response('private credentials', status),
          ),
        );
        await expectLater(
          api.users('old'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', status)
                .having(
                  (e) => e.message,
                  'safe',
                  isNot(contains('private credentials')),
                ),
          ),
        );
      }
    },
  );
  test(
    'login parses real role/state; legacy fixtures never gain admin',
    () async {
      Map<String, dynamic> account = user;
      final api = GrowviaApi(
        baseUrl: 'https://example.test/api/v1',
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'token': 't', 'user': account}), 200),
        ),
      );
      expect((await api.login('a', 'p')).isAdmin, isTrue);
      account = {...user, 'role': 'user', 'is_active': false};
      expect((await api.me('t')).isActive, isFalse);
      account = {'id': 7, 'name': 'A', 'email': 'a'};
      expect((await api.me('t')).role, 'user');
      account = {...user, 'role': 'owner'};
      await expectLater(api.me('t'), throwsA(isA<ApiException>()));
    },
  );
  test('all CRUD envelopes and safely encoded queries', () async {
    final requests = <http.Request>[];
    final api = GrowviaApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((r) async {
        requests.add(r);
        expect(r.followRedirects, isFalse);
        expect(r.headers['Authorization'], 'Bearer old');
        final path = r.url.path;
        if (r.method == 'DELETE') return http.Response('', 204);
        if (path.endsWith('/workspace')) {
          return http.Response(
            jsonEncode({
              'settings': {'pump_mode': 'auto'},
              'counts': null,
              'recent_activities': [],
              'telemetry_available': false,
            }),
            200,
          );
        }
        if (path.endsWith('/settings')) {
          return http.Response(
            jsonEncode({
              'settings': {'pump_mode': 'auto'},
              'message': 'Saved',
            }),
            200,
          );
        }
        if (r.method == 'GET') {
          return http.Response(
            jsonEncode({
              ...page(),
              if (path.endsWith('/activities')) ...{
                'actions': <String, String>{},
                'timezone': 'UTC',
              },
              if (path.endsWith('/sessions')) 'web_supported': true,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'user': user, 'message': 'Saved', 'token': 'new'}),
          200,
        );
      }),
    );
    await api.workspace('old');
    await api.users(
      'old',
      q: 'a&role=admin #é',
      role: 'user',
      status: 'active',
      sort: 'name_desc',
      page: 2,
    );
    expect(requests.last.url.queryParameters, {
      'q': 'a&role=admin #é',
      'role': 'user',
      'status': 'active',
      'sort': 'name_desc',
      'page': '2',
    });
    await api.saveUser(
      'old',
      name: 'A',
      email: 'a',
      role: 'user',
      password: ' p ',
    );
    expect(requests.last.method, 'POST');
    expect(jsonDecode(requests.last.body), {
      'name': 'A',
      'email': 'a',
      'role': 'user',
      'password': ' p ',
    });
    await api.saveUser(
      'old',
      id: 7,
      name: 'A',
      email: 'a',
      role: 'admin',
      adminPassword: ' fresh ',
    );
    expect(requests.last.url.path, '/api/v1/users/7');
    expect(requests.last.method, 'PATCH');
    expect(jsonDecode(requests.last.body), {
      'name': 'A',
      'email': 'a',
      'role': 'admin',
      'admin_password': ' fresh ',
    });
    await api.setUserActive('old', 8, false);
    expect(requests.last.url.path, '/api/v1/users/8/status');
    expect(jsonDecode(requests.last.body), {'is_active': false});
    await api.deleteUser('old', 8);
    expect(requests.last.method, 'DELETE');
    await api.activities(
      'old',
      q: '&',
      action: 'a/b',
      from: '2026-09-01',
      to: '2026-09-17',
      page: 3,
    );
    expect(requests.last.url.queryParameters, {
      'q': '&',
      'action': 'a/b',
      'from': '2026-09-01',
      'to': '2026-09-17',
      'page': '3',
    });
    expect(await api.systemSettings('old'), {'pump_mode': 'auto'});
    await api.saveSystemSettings('old', 'notifications', {'notif_pompa': true});
    expect(jsonDecode(requests.last.body), {
      'section': 'notifications',
      'values': {'notif_pompa': true},
    });
    expect(
      (await api.updateProfile(
        'old',
        name: 'A',
        email: 'a',
        currentPassword: ' p ',
      )).token,
      'new',
    );
    expect(requests.last.url.path, '/api/v1/account/profile');
    expect(jsonDecode(requests.last.body), {
      'name': 'A',
      'email': 'a',
      'current_password': ' p ',
    });
    await api.changePassword(
      'old',
      currentPassword: 'p',
      password: 'n',
      confirmation: 'n',
    );
    expect(requests.last.url.path, '/api/v1/account/password');
    expect(jsonDecode(requests.last.body), {
      'current_password': 'p',
      'password': 'n',
      'password_confirmation': 'n',
    });
    expect((await api.sessions('old', page: 2)).webSupported, isTrue);
    expect(requests.last.url.queryParameters, {'page': '2'});
    await api.revokeOtherSessions('old', 'p');
    expect(requests.last.url.path, '/api/v1/account/sessions/revoke-others');
    expect(requests.last.method, 'POST');
    expect(jsonDecode(requests.last.body), {'current_password': 'p'});
  });
  test(
    '422 preserves safe validation fields and status; secrets never escape',
    () async {
      final api = GrowviaApi(
        baseUrl: 'https://example.test/api/v1',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': 'The name field is required.',
              'errors': {
                'name': ['The name field is required.'],
                'password': ['Invalid secret-value'],
              },
            }),
            422,
          ),
        ),
      );
      await expectLater(
        api.login('a', 'secret-value'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 422)
              .having((e) => e.fieldErrors['name'], 'fields', [
                'The name field is required.',
              ])
              .having(
                (e) => e.fieldErrors.toString(),
                'safe',
                isNot(contains('secret-value')),
              )
              .having(
                (e) => e.message,
                'message',
                'The name field is required.',
              ),
        ),
      );
    },
  );
  test('recovery uses anonymous JSON API without following links', () async {
    final requests = <http.Request>[];
    final api = GrowviaApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((r) async {
        requests.add(r);
        expect(r.headers['Authorization'], isNull);
        expect(r.followRedirects, isFalse);
        return http.Response('{"message":"OK"}', 200);
      }),
    );
    await api.requestPasswordReset('a@example.test');
    expect(requests.last.url.path, '/api/v1/auth/forgot-password');
    expect(jsonDecode(requests.last.body), {'email': 'a@example.test'});
    await api.resetPassword(
      email: 'a',
      token: 'reset-token',
      password: ' p ',
      confirmation: ' p ',
    );
    expect(requests.last.url.path, '/api/v1/auth/reset-password');
    expect(jsonDecode(requests.last.body), {
      'email': 'a',
      'token': 'reset-token',
      'password': ' p ',
      'password_confirmation': ' p ',
    });
  });
  test('malformed successful data never becomes an empty success', () async {
    final api = GrowviaApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    for (final future in [
      api.workspace('t'),
      api.users('t'),
      api.activities('t'),
      api.sessions('t'),
      api.systemSettings('t'),
      api.updateProfile('t', name: 'A', email: 'a'),
      api.requestPasswordReset('a'),
    ]) {
      await expectLater(future, throwsA(isA<ApiException>()));
    }
  });
}
