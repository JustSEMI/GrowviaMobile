import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growvia_mobile/core/app_controller.dart';
import 'package:growvia_mobile/data/api_client.dart';

const user = {
  'id': 7,
  'name': 'A',
  'email': 'a@example.test',
  'role': 'admin',
  'is_active': true,
};
http.Response jsonResponse(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);
Map<String, dynamic> workspace([int count = 1]) => {
  'settings': {'pump_mode': 'auto'},
  'counts': {'users_total': count},
  'recent_activities': [],
  'telemetry_available': false,
};
Map<String, dynamic> page() => {
  'data': [],
  'meta': {'current_page': 1, 'last_page': 1, 'per_page': 15, 'total': 0},
};
final cancelled = throwsA(
  isA<ApiException>().having((e) => e.status, 'status', 401),
);

class TestStorage extends FlutterSecureStorage {
  String? value;
  bool failWrite = false, failDelete = false;
  Completer<void>? writeGate, deleteGate;
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => value;
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await writeGate?.future;
    this.value = value;
    if (failWrite) throw StateError('secure store failure');
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await deleteGate?.future;
    if (failDelete) throw StateError('secure store failure');
    value = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'growvia.api_url': 'https://example.test/api/v1',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });
  Future<AppController> signedIn(
    Future<http.Response> Function(http.Request) handler, {
    TestStorage? storage,
    List<http.Request>? requests,
  }) async {
    final app = AppController(
      storage: storage,
      client: MockClient((r) async {
        requests?.add(r);
        if (r.url.path.endsWith('/auth/login')) {
          return jsonResponse({'user': user, 'token': 'old'});
        }
        if (r.url.path.endsWith('/readings')) return jsonResponse({'data': []});
        return handler(r);
      }),
    );
    addTearDown(app.dispose);
    await app.initialize();
    await app.login('a', 'p');
    return app;
  }

  test(
    'explicit workspace, role, live writes and count refresh only when loaded',
    () async {
      final requests = <http.Request>[];
      var count = 1;
      final gate = Completer<http.Response>();
      final app = await signedIn((r) async {
        if (r.url.path.endsWith('/workspace')) {
          return jsonResponse(workspace(count));
        }
        if (r.method == 'DELETE') {
          count = 0;
          return http.Response('', 204);
        }
        return gate.future;
      }, requests: requests);
      expect(requests.map((r) => r.url.path), [
        '/api/v1/auth/login',
        '/api/v1/readings',
      ]);
      expect(app.isAdmin, isTrue);
      expect(app.workspace, isNull);
      await app.loadWorkspace();
      expect(app.workspace!.counts!['users_total'], 1);
      final pending = app.saveUser(
        name: 'B',
        email: 'b',
        role: 'user',
        password: 'p',
      );
      await Future<void>.delayed(Duration.zero);
      expect(app.workspace!.counts!['users_total'], 1);
      count = 2;
      gate.complete(
        jsonResponse({
          'user': {...user, 'id': 8},
          'message': 'Saved',
        }),
      );
      await pending;
      expect(app.workspace!.counts!['users_total'], 2);
      await app.deleteUser(8);
      expect(app.workspace!.counts!['users_total'], 0);
    },
  );
  for (final name in [
    'users',
    'activities',
    'settings',
    'sessions',
    'workspace',
  ]) {
    test(
      'late $name read after logout throws cancellation and retains no private data',
      () async {
        final response = Completer<http.Response>();
        final app = await signedIn(
          (r) async => r.url.path.endsWith('/auth/logout')
              ? http.Response('', 204)
              : response.future,
        );
        final pending = switch (name) {
          'users' => app.loadUsers(),
          'activities' => app.loadActivities(),
          'settings' => app.loadSystemSettings(),
          'sessions' => app.loadSessions(),
          _ => app.loadWorkspace(),
        };
        final check = expectLater(pending, cancelled);
        await app.logout();
        response.complete(
          jsonResponse(switch (name) {
            'settings' => {'settings': <String, String>{}},
            'workspace' => workspace(),
            _ => {
              ...page(),
              'actions': <String, String>{},
              'timezone': 'UTC',
              'web_supported': true,
            },
          }),
        );
        await check;
        expect(app.session, isNull);
        expect(app.workspace, isNull);
      },
    );
  }
  test('401 clears all private memory before slow failing secure deletion; 403 does not', () async {
    final storage = TestStorage();
    var status = 200;
    final app = await signedIn(
      (r) async =>
          status == 200 ? jsonResponse(workspace()) : jsonResponse({}, status),
      storage: storage,
    );
    await app.loadWorkspace();
    status = 403;
    await expectLater(
      app.loadUsers(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
    );
    expect(app.session, isNotNull);
    expect(app.workspace, isNotNull);
    status = 401;
    storage.deleteGate = Completer<void>();
    storage.failDelete = true;
    final check = expectLater(app.loadUsers(), cancelled);
    await Future<void>.delayed(Duration.zero);
    expect(app.session, isNull);
    expect(app.workspace, isNull);
    expect(app.readings, isEmpty);
    expect(app.loadingWorkspace, isFalse);
    storage.deleteGate!.complete();
    await check;
  });
  test('rotating response persists before adoption and stays bound to original origin', () async {
    final storage = TestStorage();
    final requests = <http.Request>[];
    final app = await signedIn(
      (r) async => jsonResponse({
        'user': {...user, 'name': 'B'},
        'token': 'new',
        'message': 'Saved',
      }),
      storage: storage,
      requests: requests,
    );
    app.preferences.apiUrl = 'https://other.test/api/v1';
    storage.writeGate = Completer<void>();
    final pending = app.updateProfile(
      name: 'B',
      email: 'b',
      currentPassword: 'p',
    );
    await Future<void>.delayed(Duration.zero);
    expect(app.session!.token, 'old');
    expect(app.session!.name, 'A');
    storage.writeGate!.complete();
    await pending;
    expect(app.session!.token, 'new');
    expect(app.session!.name, 'B');
    expect(
      jsonDecode(storage.value!)['base_url'],
      'https://example.test/api/v1',
    );
    expect(requests.last.url.host, 'example.test');
    expect(requests.length, 3);
  });
  test('partial secure write failure clears state and new token and revokes new credential', () async {
    final storage = TestStorage();
    final revoked = <String>[];
    final app = await signedIn((r) async {
      if (r.url.path.endsWith('/auth/logout')) {
        revoked.add(r.headers['Authorization']!);
        return http.Response('', 204);
      }
      return jsonResponse({'user': user, 'token': 'new', 'message': 'Saved'});
    }, storage: storage);
    storage.failWrite = true;
    await expectLater(
      app.changePassword(
        currentPassword: 'p',
        password: 'n',
        confirmation: 'n',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(app.session, isNull);
    expect(app.workspace, isNull);
    expect(storage.value, isNull);
    expect(revoked, contains('Bearer new'));
  });
  test('late mutation after logout and new login never overwrites new session or storage', () async {
    final storage = TestStorage();
    final response = Completer<http.Response>();
    final revoked = <String>[];
    final app = await signedIn((r) async {
      if (r.url.path.endsWith('/auth/logout')) {
        revoked.add(r.headers['Authorization']!);
        return http.Response('', 204);
      }
      return response.future;
    }, storage: storage);
    final check = expectLater(app.revokeOtherSessions('p'), cancelled);
    await app.logout();
    await app.login('a', 'p');
    response.complete(
      jsonResponse({
        'user': {...user, 'name': 'STALE'},
        'token': 'late-new',
        'message': 'Saved',
      }),
    );
    await check;
    expect(app.session!.name, 'A');
    expect(app.session!.token, 'old');
    expect(jsonDecode(storage.value!)['token'], 'old');
    expect(revoked, contains('Bearer late-new'));
  });
  test(
    'logout while rotated token is being persisted cannot resurrect it',
    () async {
      final storage = TestStorage();
      final revoked = <String>[];
      final app = await signedIn((r) async {
        if (r.url.path.endsWith('/auth/logout')) {
          revoked.add(r.headers['Authorization']!);
          return http.Response('', 204);
        }
        return jsonResponse({'user': user, 'token': 'new', 'message': 'Saved'});
      }, storage: storage);
      storage.writeGate = Completer<void>();
      final check = expectLater(app.revokeOtherSessions('p'), cancelled);
      await Future<void>.delayed(Duration.zero);
      final exiting = app.logout();
      expect(app.session, isNull);
      storage.writeGate!.complete();
      await exiting;
      await check;
      expect(app.session, isNull);
      expect(storage.value, isNull);
      expect(revoked, contains('Bearer new'));
    },
  );
  test('revocation racing an old authorized 401 cannot revive the invalidated session', () async {
    final mutation = Completer<http.Response>();
    final read = Completer<http.Response>();
    final app = await signedIn((r) async {
      if (r.url.path.endsWith('/auth/logout')) return http.Response('', 204);
      return r.method == 'GET' ? read.future : mutation.future;
    });
    final writeCheck = expectLater(app.revokeOtherSessions('p'), cancelled);
    final readCheck = expectLater(app.loadUsers(), cancelled);
    read.complete(jsonResponse({}, 401));
    await readCheck;
    expect(app.session, isNull);
    mutation.complete(
      jsonResponse({'user': user, 'token': 'new', 'message': 'Saved'}),
    );
    await writeCheck;
    expect(app.session, isNull);
  });
  test(
    'unauthenticated public reads report safe asynchronous cancellation',
    () async {
      final app = AppController(
        client: MockClient(
          (_) async => throw StateError('no request expected'),
        ),
      );
      addTearDown(app.dispose);
      await app.initialize();
      await expectLater(app.loadUsers(), cancelled);
      await expectLater(app.loadActivities(), cancelled);
      await expectLater(app.loadSystemSettings(), cancelled);
      await expectLater(app.loadSessions(), cancelled);
    },
  );
  test(
    'malformed rotating account response revokes new token and fails closed',
    () async {
      final storage = TestStorage();
      final revoked = <String>[];
      final app = await signedIn((r) async {
        if (r.url.path.endsWith('/auth/logout')) {
          revoked.add(r.headers['Authorization']!);
          return http.Response('', 204);
        }
        return jsonResponse({
          'user': {...user, 'role': 'owner'},
          'token': 'new',
          'message': 'Saved',
        });
      }, storage: storage);
      await expectLater(
        app.revokeOtherSessions('p'),
        throwsA(isA<ApiException>()),
      );
      expect(app.session, isNull);
      expect(storage.value, isNull);
      expect(revoked, contains('Bearer new'));
    },
  );
  test('security writes require a fresh token and reject wrong account responses closed', () async {
    for (final kind in ['password', 'revoke', 'email', 'wrong-user']) {
      final storage = TestStorage();
      final revoked = <String>[];
      final app = await signedIn((r) async {
        if (r.url.path.endsWith('/auth/logout')) {
          revoked.add(r.headers['Authorization']!);
          return http.Response('', 204);
        }
        return jsonResponse({
          'user': {
            ...user,
            if (kind == 'wrong-user') 'id': 8,
            if (kind == 'email') 'email': 'b',
          },
          'message': 'Saved',
          if (kind == 'wrong-user') 'token': 'new',
        });
      }, storage: storage);
      final pending = switch (kind) {
        'password' => app.changePassword(
          currentPassword: 'p',
          password: 'n',
          confirmation: 'n',
        ),
        'revoke' => app.revokeOtherSessions('p'),
        _ => app.updateProfile(
          name: 'B',
          email: kind == 'email' ? 'b' : 'a@example.test',
          currentPassword: 'p',
        ),
      };
      await expectLater(pending, throwsA(isA<ApiException>()));
      expect(app.session, isNull, reason: kind);
      expect(storage.value, isNull, reason: kind);
      if (kind == 'wrong-user') expect(revoked, contains('Bearer new'));
    }
  });
  test('late nonrotating mutation cannot change new account state', () async {
    final response = Completer<http.Response>();
    final storage = TestStorage();
    final app = await signedIn(
      (r) async => r.url.path.endsWith('/auth/logout')
          ? http.Response('', 204)
          : response.future,
      storage: storage,
    );
    final check = expectLater(
      app.updateProfile(name: 'STALE', email: 'a@example.test'),
      cancelled,
    );
    await app.logout();
    await app.login('a', 'p');
    response.complete(
      jsonResponse({
        'user': {...user, 'name': 'STALE'},
        'message': 'Saved',
      }),
    );
    await check;
    expect(app.session!.name, 'A');
    expect(jsonDecode(storage.value!)['token'], 'old');
  });
  test('old 401 after successful token rotation cannot invalidate adopted credential', () async {
    final response = Completer<http.Response>();
    final storage = TestStorage();
    final app = await signedIn(
      (r) async => r.method == 'GET'
          ? response.future
          : jsonResponse({'user': user, 'token': 'new', 'message': 'Saved'}),
      storage: storage,
    );
    final check = expectLater(app.loadUsers(), cancelled);
    await app.revokeOtherSessions('p');
    response.complete(jsonResponse({}, 401));
    await check;
    expect(app.session!.token, 'new');
    expect(jsonDecode(storage.value!)['token'], 'new');
  });
  test('all nonrotating writes use live responses; failed updates never change state', () async {
    final requests = <http.Request>[];
    var status = 200;
    final app = await signedIn((r) async {
      if (status != 200) {
        return jsonResponse({
          'message': 'Invalid name',
          'errors': {
            'name': ['Invalid name'],
          },
        }, status);
      }
      if (r.url.path.endsWith('/settings')) {
        return jsonResponse({
          'settings': {'pump_mode': 'manual'},
          'message': 'Saved',
        });
      }
      return jsonResponse({
        'user': {
          ...user,
          'id': r.url.path.endsWith('/8/status') ? 8 : 7,
          'name': 'B',
        },
        'message': 'Saved',
      });
    }, requests: requests);
    status = 422;
    await expectLater(
      app.updateProfile(name: 'B', email: 'b'),
      throwsA(
        isA<ApiException>().having((e) => e.fieldErrors['name'], 'fields', [
          'Invalid name',
        ]),
      ),
    );
    expect(app.session!.name, 'A');
    status = 200;
    await app.saveUser(id: 7, name: 'B', email: 'b', role: 'admin');
    expect(app.session!.name, 'B');
    await app.setUserActive(8, false);
    expect(requests.last.url.path, '/api/v1/users/8/status');
    await app.saveSystemSettings('soil', {'pump_mode': 'manual'});
    expect(requests.last.url.path, '/api/v1/settings');
    expect(app.workspace, isNull);
    expect(requests.where((r) => r.url.path.endsWith('/workspace')), isEmpty);
  });
  test('anonymous recovery uses configured endpoint and does not modify current account', () async {
    final requests = <http.Request>[];
    final app = await signedIn(
      (r) async => jsonResponse({'message': 'OK'}),
      requests: requests,
    );
    app.preferences.apiUrl = 'https://recovery.test/api/v1';
    await app.requestPasswordReset('a');
    await app.resetPassword(
      email: 'a',
      token: 'r',
      password: 'n',
      confirmation: 'n',
    );
    expect(requests.last.url.host, 'recovery.test');
    expect(requests.last.headers['Authorization'], isNull);
    expect(app.session!.token, 'old');
    app.preferences.apiUrl = 'https://user:password@invalid.test/api/v1';
    await expectLater(
      app.requestPasswordReset('a'),
      throwsA(isA<ApiException>()),
    );
  });
}
