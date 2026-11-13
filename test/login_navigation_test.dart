import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/core/app_controller.dart';
import 'package:growvia_mobile/data/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage yang operasi tulisnya tak pernah selesai sampai test
/// menuntaskannya: simulasi platform call yang menggantung di perangkat.
class HangOnWriteStorage extends FlutterSecureStorage {
  final Completer<void> writeGate = Completer<void>();

  @override
  Future<void> write({
    required String key,
    String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => writeGate.future;
}

/// Secure storage yang selalu gagal menulis.
class WriteFailingStorage extends FlutterSecureStorage {
  int writes = 0;

  @override
  Future<void> write({
    required String key,
    String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes++;
    throw StateError('test storage unavailable');
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'growvia.api_url': 'https://growvia.example/api/v1',
    });
  });

  http.Client mockApi({
    void Function(http.Request request)? onRequest,
  }) => MockClient((request) async {
    onRequest?.call(request);
    if (request.url.path.endsWith('/auth/login')) {
      return http.Response(
        jsonEncode({
          'token': 'fresh-token',
          'user': {
            'id': 7,
            'name': 'Petani Uji',
            'email': 'petani@example.test',
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
          'settings': <String, String>{},
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

  test('login membuka sesi sebelum penyimpanan secure storage selesai', () async {
    final storage = HangOnWriteStorage();
    final app = AppController(storage: storage, client: mockApi());
    addTearDown(app.dispose);
    await app.initialize();

    final pending = app.login('petani@example.test', 'test-password');
    // Beri kesempatan alur login mencapai titik pembukaan sesi.
    for (var i = 0; i < 50 && app.session == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      app.session,
      isNotNull,
      reason: 'UI harus berpindah ke workspace tanpa menunggu secure storage.',
    );

    storage.writeGate.complete();
    await pending;
    expect(app.session, isNotNull);
    expect(app.session!.token, 'fresh-token');
  });

  test('gagal menyimpan menutup sesi optimistis dan mencabut token', () async {
    final storage = WriteFailingStorage();
    final revoked = <String>[];
    final app = AppController(
      storage: storage,
      client: mockApi(
        onRequest: (request) {
          if (request.url.path.endsWith('/auth/logout')) {
            revoked.add(request.headers['Authorization'] ?? '');
          }
        },
      ),
    );
    addTearDown(app.dispose);
    await app.initialize();

    final pending = app.login('petani@example.test', 'test-password');

    Object? caught;
    try {
      await pending;
    } catch (error) {
      caught = error;
    }
    expect(caught, isA<ApiException>());
    expect(app.session, isNull, reason: 'Sesi gagal disimpan harus ditutup.');
    expect(revoked, isNotEmpty);
  });
}
