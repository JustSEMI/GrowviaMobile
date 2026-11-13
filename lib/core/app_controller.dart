import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../data/api_client.dart';
import '../data/reading.dart';
import '../data/workspace_models.dart';
import 'preferences.dart';

class _Access {
  const _Access(this.api, this.session, this.generation);
  final GrowviaApi api;
  final AccountSession session;
  final int generation;
}

class AppController extends ChangeNotifier {
  AppController({http.Client? client, FlutterSecureStorage? storage})
    : client = client ?? http.Client(),
      _ownsClient = client == null,
      storage = storage ?? const FlutterSecureStorage();

  final AppPreferences preferences = AppPreferences();
  final http.Client client;
  final bool _ownsClient;
  final FlutterSecureStorage storage;
  AccountSession? session;
  GrowviaApi? _api;
  String? _sessionBase;
  List<Reading> readings = const [];
  WorkspaceData? workspace;
  bool preview = false;
  bool loadingReadings = false;
  bool loadingWorkspace = false;
  bool initializing = true;
  bool authenticating = false;
  String? dataError;
  String? workspaceError;
  String? message;
  bool _disposed = false;
  int _generation = 0;
  int _workspaceRequest = 0;
  Future<void> _storageTail = Future<void>.value();

  bool get workspaceOpen => preview || session != null;
  bool get isAdmin => session?.isAdmin ?? false;
  static const _cancelled = ApiException(
    'Sesi telah berubah. Silakan masuk kembali.',
    status: 401,
  );

  // Serialisasi operasi penulisan DAN penghapusan secure storage. Operasi yang
  // dibatalkan harus selesai bersih sebelum akun baru menyimpan kredensialnya.
  Future<T> _store<T>(Future<T> Function() operation) {
    final result = _storageTail.then((_) => operation());
    _storageTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  bool _current(_Access access) =>
      !_disposed &&
      access.generation == _generation &&
      identical(access.api, _api) &&
      session?.token == access.session.token &&
      session?.userId == access.session.userId;

  _Access _access() {
    final account = session;
    final api = _api;
    if (_disposed || account == null || api == null) throw _cancelled;
    return _Access(api, account, _generation);
  }

  void _check(_Access access) {
    if (!_current(access)) throw _cancelled;
  }

  void _clearPrivate() {
    session = null;
    _api = null;
    _sessionBase = null;
    preview = false;
    readings = const [];
    workspace = null;
    dataError = null;
    workspaceError = null;
    loadingReadings = false;
    loadingWorkspace = false;
    _workspaceRequest++;
  }

  Future<void> _invalidate(_Access access) async {
    if (!_current(access)) return;
    final generation = ++_generation;
    _clearPrivate();
    message = 'Sesi berakhir atau akses akun dicabut. Silakan masuk kembali.';
    final deletion = _store(() => storage.delete(key: 'growvia.session'));
    _notify(); // Beri tahu UI sebelum operasi secure storage selesai atau gagal.
    try {
      await deletion;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        message =
            'Sesi ditutup. Penyimpanan sesi lokal belum dapat dibersihkan.';
        _notify();
      }
    }
  }

  Future<T> _read<T>(_Access access, Future<T> Function() operation) async {
    _check(access);
    try {
      final result = await operation();
      _check(access);
      return result;
    } on ApiException catch (error) {
      _check(access);
      if (error.status == 401) await _invalidate(access);
      rethrow;
    }
  }

  Future<void> _revoke(GrowviaApi api, String token) async {
    try {
      await api.logout(token);
    } catch (_) {
      // Jangan pernah memulihkan akun yang dibatalkan jika pembersihan remote tidak tersedia.
    }
  }

  Future<void> initialize() async {
    final generation = _generation;
    try {
      await preferences.load();
      if (_disposed ||
          generation != _generation ||
          preferences.apiUrl.isEmpty) {
        return;
      }
      final saved = await _store(() => storage.read(key: 'growvia.session'));
      if (_disposed || generation != _generation || saved == null) return;
      final data = jsonDecode(saved);
      if (data is! Map<String, dynamic> ||
          data['base_url'] != preferences.apiUrl ||
          data['token'] is! String ||
          (data['token'] as String).trim().isEmpty ||
          (data['token'] as String).contains(RegExp(r'[\r\n]'))) {
        await _store(() => storage.delete(key: 'growvia.session'));
        return;
      }
      final base = preferences.apiUrl;
      final api = GrowviaApi(baseUrl: base, client: client);
      final verified = await api.me(data['token'] as String);
      if (_disposed || generation != _generation) return;
      _api = api;
      _sessionBase = base;
      session = verified;
      await refresh();
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return;
      message = 'Sesi belum dapat dipulihkan. ${error.message}';
      if (error.status == 401) {
        _clearPrivate();
        try {
          await _store(() => storage.delete(key: 'growvia.session'));
        } catch (_) {
          /* Closed. */
        }
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        message = 'Penyimpanan sesi tidak dapat dibaca. Silakan masuk kembali.';
      }
    } finally {
      if (!_disposed) {
        initializing = false;
        _notify();
      }
    }
  }

  void enterPreview() {
    if (session != null || initializing || authenticating || _disposed) return;
    preview = true;
    readings = const [];
    workspace = null;
    dataError = null;
    workspaceError = null;
    _notify();
  }

  Future<void> login(String email, String password) async {
    if (initializing || authenticating || _disposed) {
      throw const ApiException('Tunggu proses akun sebelumnya selesai.');
    }
    final base = preferences.apiUrl;
    if (base.isEmpty) {
      throw const ApiException('Atur alamat API sebelum masuk.');
    }
    final api = GrowviaApi(baseUrl: base, client: client);
    final generation = ++_generation;
    _clearPrivate();
    authenticating = true;
    _notify();
    AccountSession? next;
    var adopted = false;
    try {
      next = await api.login(email, password);
      if (_disposed || generation != _generation) return;
      final credential = next;
      // Buka ruang kerja SEKETIKA: UI tidak boleh menunggu secure storage,
      // yang bisa lambat atau macet di perangkat nyata. Persist tetap
      // terserialisasi di bawah; bila gagal, sesi dicabut di `finally`.
      _api = api;
      _sessionBase = base;
      session = credential;
      preview = false;
      message = null;
      _notify();
      adopted = await _store(() async {
        if (_disposed || generation != _generation) return false;
        try {
          await storage.write(
            key: 'growvia.session',
            value: jsonEncode({'base_url': base, 'token': credential.token}),
          );
        } catch (_) {
          try {
            await storage.delete(key: 'growvia.session');
          } catch (_) {
            /* Closed. */
          }
          throw const ApiException(
            'Sesi tidak dapat disimpan dengan aman. Silakan masuk kembali.',
          );
        }
        return true;
        // Antrean storage tidak boleh menggantung alur login selamanya:
        // operasi platform yang tak selesai dalam 10 detik dianggap gagal.
      }).timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (!adopted) {
        if (generation == _generation && message == null) {
          message =
              'Sesi tidak dapat disimpan dengan aman. Silakan masuk kembali.';
        }
        return;
      }
      await refresh(); // Pertahankan urutan alur request login asli.
    } finally {
      if (!adopted && next != null) {
        // Simpan gagal/dibatalkan: cabut kredensial baru. Bersihkan sesi
        // optimistis hanya bila sesi ini masih yang aktif.
        if (generation == _generation && session == next) {
          _clearPrivate();
        }
        await _revoke(api, next.token);
      }
      authenticating = false;
      _notify();
    }
  }

  Future<void> refresh() async {
    if (session == null || _api == null || loadingReadings || _disposed) return;
    final access = _access();
    loadingReadings = true;
    dataError = null;
    _notify();
    try {
      final next = await _read(
        access,
        // Batas atas API (/v1/readings) supaya rentang grafik 7 hari tidak
        // terpotong di 300 pembacaan bawaan.
        () => access.api.readings(access.session.token, limit: 1000),
      );
      _check(access);
      readings = next;
    } on ApiException catch (error) {
      if (_current(access)) {
        readings = const [];
        dataError = error.message;
      }
    } finally {
      if (_current(access)) {
        loadingReadings = false;
        _notify();
      }
    }
  }

  Future<void> loadWorkspace() async {
    final access = _access();
    final request = ++_workspaceRequest;
    loadingWorkspace = true;
    workspaceError = null;
    _notify();
    try {
      final next = await _read(
        access,
        () => access.api.workspace(access.session.token),
      );
      _check(access);
      if (request == _workspaceRequest) workspace = next;
    } on ApiException catch (error) {
      if (_current(access) && request == _workspaceRequest) {
        workspaceError = error.message;
      }
      rethrow;
    } finally {
      if (_current(access) && request == _workspaceRequest) {
        loadingWorkspace = false;
        _notify();
      }
    }
  }

  Future<ApiPage<UserAccount>> loadUsers({
    String q = '',
    String role = '',
    String status = '',
    String sort = 'newest',
    int page = 1,
  }) async {
    final access = _access();
    return _read(
      access,
      () => access.api.users(
        access.session.token,
        q: q,
        role: role,
        status: status,
        sort: sort,
        page: page,
      ),
    );
  }

  Future<ApiPage<ActivityEntry>> loadActivities({
    String q = '',
    String action = '',
    String from = '',
    String to = '',
    int page = 1,
  }) async {
    final access = _access();
    return _read(
      access,
      () => access.api.activities(
        access.session.token,
        q: q,
        action: action,
        from: from,
        to: to,
        page: page,
      ),
    );
  }

  Future<Map<String, String>> loadSystemSettings() async {
    final access = _access();
    return _read(access, () => access.api.systemSettings(access.session.token));
  }

  Future<BackupData> loadBackups() async {
    final access = _access();
    return _read(access, () => access.api.backups(access.session.token));
  }

  Future<({BackupFile backup, String message})> createBackup() async {
    final access = _access();
    return _read(access, () => access.api.createBackup(access.session.token));
  }

  Future<void> deleteBackup(String name) async {
    final access = _access();
    return _read(access, () async {
      await access.api.deleteBackup(access.session.token, name);
    });
  }

  Future<List<int>> downloadBackup(String name, String format) async {
    final access = _access();
    return _read(
      access,
      () => access.api.downloadBackup(access.session.token, name, format),
    );
  }

  Future<ApiPage<DeviceSession>> loadSessions({int page = 1}) async {
    final access = _access();
    return _read(
      access,
      () => access.api.sessions(access.session.token, page: page),
    );
  }

  Future<void> _refreshWorkspaceAfterWrite() async {
    if (workspace == null && !loadingWorkspace) return;
    try {
      await loadWorkspace();
    } on ApiException catch (error) {
      // Penulisan yang berhasil tidak boleh dianggap gagal hanya karena pembacaan
      // lanjutannya gagal. Error pembacaan diekspos workspace secara terpisah.
      if (error.status == 401) rethrow;
    }
  }

  Future<void> _adopt(
    _Access access,
    AccountMutation result, {
    bool requireRotation = false,
  }) async {
    final rotated =
        result.token != null && result.token != access.session.token;
    var adopted = false;
    try {
      _check(access);
      if (result.user.id != access.session.userId ||
          !result.user.isActive ||
          ((requireRotation || result.user.email != access.session.email) &&
              !rotated)) {
        await _invalidate(access);
        await _revoke(access.api, access.session.token);
        throw const ApiException(
          'Sesi tidak dapat diperbarui dengan aman. Silakan masuk kembali.',
          status: 401,
        );
      }
      if (rotated) {
        await _store(() async {
          _check(access);
          try {
            await storage.write(
              key: 'growvia.session',
              value: jsonEncode({
                'base_url': _sessionBase,
                'token': result.token,
              }),
            );
          } catch (_) {
            if (_current(access)) {
              ++_generation;
              _clearPrivate();
              message = 'Sesi tidak dapat disimpan dengan aman. Silakan masuk kembali.';
              _notify();
            }
            try {
              await storage.delete(key: 'growvia.session');
            } catch (_) {
              /* Closed. */
            }
            throw const ApiException(
              'Sesi tidak dapat disimpan dengan aman. Silakan masuk kembali.',
            );
          }
          if (!_current(access)) {
            try {
              await storage.delete(key: 'growvia.session');
            } catch (_) {
              /* Closed. */
            }
            throw _cancelled;
          }
          session = result.session(access.session.token);
          ++_generation;
          loadingReadings = false;
          loadingWorkspace = false;
          adopted = true;
        });
      } else {
        _check(access);
        session = result.session(access.session.token);
        adopted = true;
      }
      _notify();
    } finally {
      if (rotated && !adopted) await _revoke(access.api, result.token!);
    }
  }

  Future<void> _accountWrite(
    Future<AccountMutation> Function(_Access) operation, {
    bool self = true,
    bool requireRotation = false,
  }) async {
    final access = _access();
    AccountMutation result;
    try {
      result = await operation(access);
    } on ApiException catch (error) {
      _check(access);
      if (error.status == 401) await _invalidate(access);
      rethrow;
    }
    // Periksa/terapkan secara mandiri alih-alih via _read: respons kedaluwarsa
    // sekalipun bisa membawa token baru yang wajib dicabut sebelum dibuang.
    if (self) {
      await _adopt(access, result, requireRotation: requireRotation);
    } else {
      if (result.token != null) {
        await _revoke(access.api, result.token!);
        _check(access);
        throw const ApiException(
          'Respons akun tidak sesuai kontrak API mobile.',
        );
      }
      _check(access);
    }
    final current = _access();
    await _refreshWorkspaceAfterWrite();
    _check(current);
  }

  Future<void> saveUser({
    int? id,
    required String name,
    required String email,
    required String role,
    String? password,
    String? adminPassword,
  }) => _accountWrite(
    (a) => a.api.saveUser(
      a.session.token,
      id: id,
      name: name,
      email: email,
      role: role,
      password: password,
      adminPassword: adminPassword,
    ),
    self: id != null && id == session?.userId,
    requireRotation: password != null && password.isNotEmpty,
  );

  Future<void> setUserActive(int id, bool active) => _accountWrite(
    (a) => a.api.setUserActive(a.session.token, id, active),
    self: id == session?.userId,
  );

  Future<void> deleteUser(int id) async {
    final access = _access();
    await _read(access, () => access.api.deleteUser(access.session.token, id));
    _check(access);
    await _refreshWorkspaceAfterWrite();
    _check(access);
  }

  Future<void> saveSystemSettings(
    String section,
    Map<String, dynamic> values,
  ) async {
    final access = _access();
    await _read(
      access,
      () =>
          access.api.saveSystemSettings(access.session.token, section, values),
    );
    _check(access);
    await _refreshWorkspaceAfterWrite();
    _check(access);
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    String? currentPassword,
  }) => _accountWrite(
    (a) => a.api.updateProfile(
      a.session.token,
      name: name,
      email: email,
      currentPassword: currentPassword,
    ),
  );

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String confirmation,
  }) => _accountWrite(
    (a) => a.api.changePassword(
      a.session.token,
      currentPassword: currentPassword,
      password: password,
      confirmation: confirmation,
    ),
    requireRotation: true,
  );

  Future<void> revokeOtherSessions(String currentPassword) => _accountWrite(
    (a) => a.api.revokeOtherSessions(a.session.token, currentPassword),
    requireRotation: true,
  );

  GrowviaApi _anonymousApi() =>
      GrowviaApi(baseUrl: preferences.apiUrl, client: client);

  Future<void> requestPasswordReset(String email) async {
    await _anonymousApi().requestPasswordReset(email);
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String confirmation,
    String? expectedBaseUrl,
  }) async {
    if (expectedBaseUrl != null && expectedBaseUrl != preferences.apiUrl) {
      throw const ApiException(
        'Alamat API berubah. Baca ulang tautan pemulihan.',
      );
    }
    await _anonymousApi().resetPassword(
      email: email,
      token: token,
      password: password,
      confirmation: confirmation,
    );
  }

  Future<void> logout() async {
    final current = session;
    final api = _api;
    final generation = ++_generation;
    _clearPrivate();
    final deletion = _store(() => storage.delete(key: 'growvia.session'));
    _notify();
    var localDeleted = true;
    var remoteRevoked = true;
    try {
      await deletion;
    } catch (_) {
      localDeleted = false;
    }
    if (current != null && api != null) {
      try {
        await api.logout(current.token);
      } catch (_) {
        remoteRevoked = false;
      }
    }
    if (_disposed || generation != _generation) return;
    message = !localDeleted
        ? 'Keluar dari tampilan. Penyimpanan sesi lokal belum dapat dibersihkan.'
        : !remoteRevoked
        ? 'Keluar dari perangkat ini. Pencabutan token di server belum dapat dikonfirmasi.'
        : null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _clearPrivate();
    preferences.dispose();
    if (_ownsClient) client.close();
    super.dispose();
  }
}
