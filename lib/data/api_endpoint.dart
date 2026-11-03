import 'package:flutter/foundation.dart';

/// Kebijakan endpoint tunggal untuk transport, preferensi, dan validasi pengaturan.
class ApiEndpoint {
  const ApiEndpoint({this.allowDebugHttp = true});

  /// Dapat menonaktifkan HTTP lokal untuk pengujian, tetapi tidak bisa diaktifkan di luar mode debug.
  final bool allowDebugHttp;
  bool get localHttpAllowed => kDebugMode && allowDebugHttp;

  static const localHosts = {'127.0.0.1', 'localhost', '10.0.2.2'};

  /// URL produksi bawaan untuk build release/profile.
  static const productionBaseUrl = 'https://growvia.justsemi.ai.id/api/v1';

  /// Override saat build: `--dart-define=GROWVIA_API_URL=...`.
  static const overrideBaseUrl = String.fromEnvironment('GROWVIA_API_URL');

  String get defaultBaseUrl {
    final candidate = overrideBaseUrl.isNotEmpty
        ? overrideBaseUrl
        : localHttpAllowed
        ? 'http://127.0.0.1:8000/api/v1'
        : productionBaseUrl;
    return validate(candidate) == null ? candidate : '';
  }

  String get validationMessage => localHttpAllowed
      ? 'Gunakan HTTPS, atau HTTP lokal khusus debug (127.0.0.1, localhost, 10.0.2.2). Tanpa kredensial, query, fragmen, atau traversal path.'
      : 'Gunakan HTTPS tanpa kredensial, query, fragmen, atau traversal path.';

  String? validate(String value, {bool allowEmpty = false}) {
    // Periksa penulisan asli sebelum Uri menormalisasi segmen dot,
    // host ber-escape, user-info kosong, atau backslash.
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      return validationMessage;
    }
    final text = value.trim();
    if (text.isEmpty) return allowEmpty ? null : validationMessage;
    final match = RegExp(
      r'^(https?)://([^/?#]+)(/[^?#]*)?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return validationMessage;
    final authority = match.group(2)!;
    final path = match.group(3) ?? '';
    // Base path API adalah segmen URL literal, bukan input rute ter-encode.
    // Tolak karakter escape agar proses decoding berulang tidak menyembunyikan traversal.
    if (RegExp(r'[@%\\\s]').hasMatch(authority) ||
        authority.endsWith(':') ||
        !RegExp(r'^[a-zA-Z0-9/._~-]*$').hasMatch(path) ||
        path.split('/').any((segment) => segment == '.' || segment == '..')) {
      return validationMessage;
    }
    try {
      final uri = Uri.parse(text);
      if (!uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          uri.port < 1 ||
          uri.port > 65535) {
        return validationMessage;
      }
      if (uri.scheme == 'https') return null;
      if (uri.scheme == 'http' &&
          localHttpAllowed &&
          localHosts.contains(uri.host)) {
        return null;
      }
    } on FormatException {
      return validationMessage;
    }
    return validationMessage;
  }

  Uri parse(String value) {
    final error = validate(value);
    if (error != null) throw FormatException(error);
    return Uri.parse('${value.trim().replaceFirst(RegExp(r'/+$'), '')}/');
  }

  bool isLocalHttp(String value) =>
      validate(value) == null && Uri.parse(value.trim()).scheme == 'http';
}
