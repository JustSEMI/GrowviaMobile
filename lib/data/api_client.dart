import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_endpoint.dart';
import 'reading.dart';
import 'workspace_models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.fieldErrors = const {}});
  final String message;
  final int? status;
  final Map<String, List<String>> fieldErrors;
  Map<String, List<String>> get errors => fieldErrors;
  @override
  String toString() => message;
}

class AccountSession {
  const AccountSession({
    required this.token,
    required this.name,
    required this.email,
    required this.userId,
    this.role = 'user',
    this.isActive = true,
  });
  final String token;
  final String name;
  final String email;
  final int userId;
  final String role;
  final bool isActive;
  bool get isAdmin => role == 'admin';
}

class AccountMutation {
  const AccountMutation({required this.user, this.token});
  final UserAccount user;
  final String? token;
  AccountSession session(String currentToken) => AccountSession(
    token: token ?? currentToken,
    name: user.name,
    email: user.email,
    userId: user.id,
    role: user.role,
    isActive: user.isActive,
  );
}

class GrowviaApi {
  GrowviaApi({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    bool allowDebugHttp = true,
  }) : base = _parseBase(baseUrl, allowDebugHttp),
       _client = client ?? http.Client();

  static Uri _parseBase(String value, bool allowDebugHttp) {
    try {
      return ApiEndpoint(allowDebugHttp: allowDebugHttp).parse(value);
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  final Uri base;
  final http.Client _client;
  final Duration timeout;

  /// Khusus pemeriksaan eksplisit; menyimpan pengaturan lokal tidak pernah memanggil server.
  Future<void> health() async {
    final response = await _json('GET', 'health');
    if (response['app'] != 'Growvia' ||
        response['api_version'] != 'v1' ||
        response['status'] != 'ok') {
      throw const ApiException('Respons health tidak sesuai API Growvia v1.');
    }
  }

  Future<AccountSession> login(String email, String password) async {
    final response = await _json(
      'POST',
      'auth/login',
      body: {
        'email': email.trim(),
        'password': password,
        'device_name': 'Growvia Mobile',
      },
    );
    return _parse(() => _account(response['user'], _token(response['token'])));
  }

  Future<AccountSession> me(String token) async {
    final response = await _json('GET', 'auth/me', token: token);
    return _parse(() => _account(response['user'], _token(token)));
  }

  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException {
      throw const ApiException('Respons tidak sesuai kontrak API mobile.');
    }
  }

  String _token(dynamic value) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException();
    }
    return value;
  }

  AccountSession _account(dynamic value, String token) {
    final json = jsonObject(value);
    // Hanya fixture pengujian login/me lama yang boleh mengabaikan role dan status aktif.
    final user = UserAccount.fromJson({
      if (!json.containsKey('role')) 'role': 'user',
      if (!json.containsKey('is_active')) 'is_active': true,
      ...json,
    });
    return AccountMutation(user: user).session(token);
  }

  String _query(String path, Map<String, String> parameters) =>
      Uri(path: path, queryParameters: parameters).toString();

  Future<WorkspaceData> workspace(String token) async {
    final json = await _json('GET', 'workspace', token: token);
    return _parse(() => WorkspaceData.fromJson(json));
  }

  Future<ApiPage<UserAccount>> users(
    String token, {
    String q = '',
    String role = '',
    String status = '',
    String sort = 'newest',
    int page = 1,
  }) async {
    final json = await _json(
      'GET',
      _query('users', {
        if (q.isNotEmpty) 'q': q,
        if (role.isNotEmpty) 'role': role,
        if (status.isNotEmpty) 'status': status,
        'sort': sort,
        'page': '$page',
      }),
      token: token,
    );
    return _parse(
      () => ApiPage<UserAccount>.fromJson(json, UserAccount.fromJson),
    );
  }

  Future<AccountMutation> _mutation(
    String method,
    String path,
    String token,
    Map<String, dynamic> body,
  ) async {
    final json = await _json(method, path, token: token, body: body);
    try {
      jsonValue<String>(json, 'message');
      return AccountMutation(
        user: UserAccount.fromJson(jsonObject(json['user'])),
        token: json.containsKey('token') ? _token(json['token']) : null,
      );
    } on FormatException {
      if (json.containsKey('token')) {
        try {
          await logout(_token(json['token']));
        } catch (_) {
          /* Fail closed. */
        }
        throw const ApiException(
          'Sesi tidak dapat diperbarui dengan aman. Silakan masuk kembali.',
          status: 401,
        );
      }
      throw const ApiException('Respons tidak sesuai kontrak API mobile.');
    }
  }

  Future<AccountMutation> saveUser(
    String token, {
    int? id,
    required String name,
    required String email,
    required String role,
    String? password,
    String? adminPassword,
  }) => _mutation(
    id == null ? 'POST' : 'PATCH',
    id == null ? 'users' : 'users/$id',
    token,
    {
      'name': name,
      'email': email,
      'role': role,
      'password': ?password,
      'admin_password': ?adminPassword,
    },
  );

  Future<AccountMutation> setUserActive(String token, int id, bool active) =>
      _mutation('PATCH', 'users/$id/status', token, {'is_active': active});

  Future<void> deleteUser(String token, int id) async {
    await _json('DELETE', 'users/$id', token: token, expectedStatus: 204);
  }

  Future<ApiPage<ActivityEntry>> activities(
    String token, {
    String q = '',
    String action = '',
    String from = '',
    String to = '',
    int page = 1,
  }) async {
    final json = await _json(
      'GET',
      _query('activities', {
        if (q.isNotEmpty) 'q': q,
        if (action.isNotEmpty) 'action': action,
        if (from.isNotEmpty) 'from': from,
        if (to.isNotEmpty) 'to': to,
        'page': '$page',
      }),
      token: token,
    );
    return _parse(() {
      if (jsonValue<String>(json, 'timezone') != 'UTC') {
        throw const FormatException();
      }
      stringMap(json['actions']);
      return ApiPage<ActivityEntry>.fromJson(json, ActivityEntry.fromJson);
    });
  }

  Future<Map<String, String>> systemSettings(String token) async {
    final json = await _json('GET', 'settings', token: token);
    return _parse(() => stringMap(json['settings']));
  }

  Future<Map<String, String>> saveSystemSettings(
    String token,
    String section,
    Map<String, dynamic> values,
  ) async {
    final json = await _json(
      'PATCH',
      'settings',
      token: token,
      body: {'section': section, 'values': values},
    );
    return _parse(() {
      jsonValue<String>(json, 'message');
      return stringMap(json['settings']);
    });
  }

  Future<AccountMutation> updateProfile(
    String token, {
    required String name,
    required String email,
    String? currentPassword,
  }) => _mutation('PATCH', 'account/profile', token, {
    'name': name,
    'email': email,
    'current_password': ?currentPassword,
  });

  Future<AccountMutation> changePassword(
    String token, {
    required String currentPassword,
    required String password,
    required String confirmation,
  }) => _mutation('PATCH', 'account/password', token, {
    'current_password': currentPassword,
    'password': password,
    'password_confirmation': confirmation,
  });

  Future<ApiPage<DeviceSession>> sessions(String token, {int page = 1}) async {
    final json = await _json(
      'GET',
      _query('account/sessions', {'page': '$page'}),
      token: token,
    );
    return _parse(() {
      jsonValue<bool>(json, 'web_supported');
      return ApiPage<DeviceSession>.fromJson(json, DeviceSession.fromJson);
    });
  }

  Future<AccountMutation> revokeOtherSessions(
    String token,
    String currentPassword,
  ) => _mutation('POST', 'account/sessions/revoke-others', token, {
    'current_password': currentPassword,
  });

  Future<void> requestPasswordReset(String email) async {
    final json = await _json(
      'POST',
      'auth/forgot-password',
      body: {'email': email},
    );
    _parse(() => jsonValue<String>(json, 'message'));
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confirmation,
  }) async {
    final json = await _json(
      'POST',
      'auth/reset-password',
      body: {
        'email': email,
        'token': token,
        'password': password,
        'password_confirmation': confirmation,
      },
    );
    _parse(() => jsonValue<String>(json, 'message'));
  }

  Future<List<Reading>> readings(String token, {String? node}) async {
    final endpoint = Uri(
      path: 'readings',
      queryParameters: {'node': ?node},
    ).toString();
    final response = await _json('GET', endpoint, token: token);
    final data = response['data'];
    if (data is! List) {
      throw const ApiException('Daftar pembacaan tidak sesuai kontrak API.');
    }
    try {
      final records = data.map((item) {
        if (item is! Map<String, dynamic>) throw const FormatException();
        return Reading.fromJson(item);
      }).toList();
      records.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return List.unmodifiable(records);
    } on FormatException {
      throw const ApiException(
        'Ada data pembacaan yang tidak valid. Tidak ditampilkan sebagai data sensor.',
      );
    }
  }

  Future<void> logout(String token) async {
    await _json('POST', 'auth/logout', token: token);
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
    int? expectedStatus,
  }) async {
    if (token != null) _parse(() => _token(token));
    final request = http.Request(method, base.resolve(endpoint))
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(timeout);
      if (response.statusCode == 404 || response.statusCode == 405) {
        throw ApiException(
          'Rute API tidak ditemukan. Periksa alamat /api/v1 dan server Laravel yang dijalankan.',
          status: response.statusCode,
        );
      }
      if (response.statusCode == 401) {
        throw const ApiException(
          'Email atau kata sandi tidak sesuai, atau sesi telah berakhir.',
          status: 401,
        );
      }
      if (response.statusCode == 403) {
        throw const ApiException(
          'Akun ini tidak diizinkan mengakses data tersebut.',
          status: 403,
        );
      }
      if (response.statusCode == 422) {
        throw _validationError(response, body, token);
      }
      if (response.statusCode == 429) {
        throw const ApiException(
          'Terlalu banyak percobaan. Tunggu sebelum mencoba lagi.',
          status: 429,
        );
      }
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw ApiException(
          'Server mengalihkan permintaan. Gunakan URL REST API langsung.',
          status: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Server belum dapat memproses permintaan. Coba kembali nanti.',
          status: response.statusCode,
        );
      }
      if (expectedStatus != null && response.statusCode != expectedStatus) {
        throw const ApiException('Respons tidak sesuai kontrak API mobile.');
      }
      if (response.statusCode == 204) return {};
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on TimeoutException {
      throw const ApiException(
        'Server terlalu lama merespons. Periksa koneksi lalu coba kembali.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Tidak dapat menghubungi server. Periksa alamat API dan koneksi.',
      );
    } on FormatException {
      throw const ApiException('Server tidak mengirim JSON API yang valid.');
    }
  }

  ApiException _validationError(
    http.Response response,
    Map<String, dynamic>? body,
    String? token,
  ) {
    const fallback = 'Periksa kembali data yang diisi.';
    final secrets = <String>[
      ?token,
      for (final entry in (body ?? <String, dynamic>{}).entries)
        if ((entry.key.contains('password') || entry.key == 'token') &&
            entry.value is String)
          entry.value as String,
    ].where((value) => value.isNotEmpty).toList();
    String safe(dynamic value) {
      if (value is! String ||
          value.trim().isEmpty ||
          value.length > 1000 ||
          value.contains(RegExp(r'[<>\x00-\x08]'))) {
        return fallback;
      }
      var text = value;
      for (final secret in secrets) {
        text = text.replaceAll(secret, '[disembunyikan]');
      }
      return text;
    }

    try {
      final json = jsonObject(jsonDecode(utf8.decode(response.bodyBytes)));
      final errors = <String, List<String>>{};
      if (json['errors'] is Map<String, dynamic>) {
        for (final entry in (json['errors'] as Map<String, dynamic>).entries) {
          if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_.]*$').hasMatch(entry.key) ||
              secrets.any((secret) => entry.key.contains(secret))) {
            continue;
          }
          if (entry.value is List &&
              (entry.value as List).every((v) => v is String)) {
            errors[entry.key] = List.unmodifiable(
              (entry.value as List).map(safe),
            );
          }
        }
      }
      return ApiException(
        safe(json['message']),
        status: 422,
        fieldErrors: Map.unmodifiable(errors),
      );
    } on FormatException {
      return const ApiException(fallback, status: 422);
    }
  }

  void close() => _client.close();
}
