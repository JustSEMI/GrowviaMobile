import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_endpoint.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences({bool allowDebugHttp = true})
    : endpointPolicy = ApiEndpoint(allowDebugHttp: allowDebugHttp),
      apiUrl = ApiEndpoint(allowDebugHttp: allowDebugHttp).defaultBaseUrl;

  final ApiEndpoint endpointPolicy;
  String apiUrl;
  ThemeMode themeMode = ThemeMode.system;
  bool loaded = false;
  String? storageError;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      apiUrl =
          preferences.getString('growvia.api_url') ??
          endpointPolicy.defaultBaseUrl;
      final mode = preferences.getString('growvia.theme');
      themeMode = ThemeMode.values.firstWhere(
        (value) => value.name == mode,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Kegagalan storage bukan bukti bahwa endpoint tidak tersimpan.
      apiUrl = '';
      storageError = 'Preferensi lokal tidak dapat dibaca. Atur ulang alamat API sebelum masuk.';
    }
    loaded = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> save(String url, ThemeMode theme) async {
    final error = endpointPolicy.validate(url, allowEmpty: true);
    if (error != null) throw FormatException(error);
    final preferences = await SharedPreferences.getInstance();
    final savedUrl = await preferences.setString('growvia.api_url', url.trim());
    final savedTheme = await preferences.setString('growvia.theme', theme.name);
    if (!savedUrl || !savedTheme) {
      throw StateError('Penyimpanan lokal tidak tersedia.');
    }
    apiUrl = url.trim();
    themeMode = theme;
    storageError = null;
    if (!_disposed) notifyListeners();
  }
}
