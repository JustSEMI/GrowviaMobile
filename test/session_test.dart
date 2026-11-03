import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growvia_mobile/core/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'growvia.api_url': 'https://growvia.example/api/v1',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('a saved token is validated against its original server before restoring an account', () async {
    FlutterSecureStorage.setMockInitialValues({
      'growvia.session': jsonEncode({
        'base_url': 'https://growvia.example/api/v1',
        'token': 'saved-test-token',
      }),
    });
    final requests = <String>[];
    final app = AppController(
      client: MockClient((request) async {
        requests.add(request.url.path);
        expect(request.headers['Authorization'], 'Bearer saved-test-token');
        if (request.url.path.endsWith('/auth/me')) {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 7,
                'name': 'Petani Uji',
                'email': 'petani@example.test',
              },
            }),
            200,
          );
        }
        return http.Response('{"data":[]}', 200);
      }),
    );
    addTearDown(app.dispose);
    await app.initialize();
    expect(app.session?.userId, 7);
    expect(app.preview, isFalse);
    expect(requests, ['/api/v1/auth/me', '/api/v1/readings']);
  });

  test('a saved token never goes to a newly configured server', () async {
    FlutterSecureStorage.setMockInitialValues({
      'growvia.session': jsonEncode({
        'base_url': 'https://old.example/api/v1',
        'token': 'saved-test-token',
      }),
    });
    var calls = 0;
    final app = AppController(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
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

  test('a late login response cannot reauthenticate after logout', () async {
    final response = Completer<http.Response>();
    final app = AppController(client: MockClient((_) => response.future));
    addTearDown(app.dispose);
    await app.initialize();
    final pending = app.login('petani@example.test', 'test-password');
    await Future<void>.delayed(Duration.zero);
    await app.logout();
    response.complete(
      http.Response(
        jsonEncode({
          'token': 'late-token',
          'user': {
            'id': 7,
            'name': 'Petani Uji',
            'email': 'petani@example.test',
          },
        }),
        200,
      ),
    );
    await pending;
    expect(app.session, isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'growvia.session'),
      isNull,
    );
  });

  test(
    'revoked access closes the account even when secure deletion fails',
    () async {
      var deny = false;
      final app = AppController(
        storage: DeleteFailingStorage(),
        client: MockClient((request) async {
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
          return http.Response(deny ? '{}' : '{"data":[]}', deny ? 401 : 200);
        }),
      );
      addTearDown(app.dispose);
      await app.initialize();
      await app.login('petani@example.test', 'test-password');
      expect(app.session, isNotNull);
      deny = true;
      await app.refresh();
      expect(app.session, isNull);
      expect(app.readings, isEmpty);
    },
  );
}

class DeleteFailingStorage extends FlutterSecureStorage {
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
    throw StateError('test storage unavailable');
  }
}
