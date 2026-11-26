import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Repositori GitHub yang menerbitkan APK rilis Growvia Mobile.
const String kGrowviaGithubRepo = String.fromEnvironment(
  'GROWVIA_GITHUB_REPO',
  defaultValue: 'JustSEMI/GrowviaMobile',
);

/// Versi cadangan saat platform tidak mendukung pembacaan PackageManager (mis. test).
const String kFallbackAppVersion = '0.1.0';
const int kFallbackBuildNumber = 1;

@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.buildNumber = 0,
  });

  final int major;
  final int minor;
  final int patch;
  final int buildNumber;

  String get versionName => '$major.$minor.$patch';
  String get label => 'v$versionName';
  String get fullLabel =>
      buildNumber > 0 ? 'v$versionName+$buildNumber' : 'v$versionName';

  static AppVersion? tryParse(String raw, {int? buildNumberOverride}) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      trimmed = trimmed.substring(1);
    }

    int parsedBuild = 0;
    final plusIndex = trimmed.indexOf('+');
    if (plusIndex >= 0) {
      parsedBuild = int.tryParse(trimmed.substring(plusIndex + 1).trim()) ?? 0;
      trimmed = trimmed.substring(0, plusIndex);
    }
    final dashIndex = trimmed.indexOf('-');
    if (dashIndex >= 0) {
      trimmed = trimmed.substring(0, dashIndex);
    }

    final parts = trimmed.split('.');
    if (parts.isEmpty || parts.length > 3) return null;
    final major = int.tryParse(parts[0]);
    final minor = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    final patch = parts.length > 2 ? int.tryParse(parts[2]) : 0;
    if (major == null || minor == null || patch == null) return null;
    if (major < 0 || minor < 0 || patch < 0) return null;

    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      buildNumber: buildNumberOverride ?? parsedBuild,
    );
  }

  bool isNewerThan(AppVersion current) => compareTo(current) > 0;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (buildNumber > 0 && other.buildNumber > 0) {
      return buildNumber.compareTo(other.buildNumber);
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch &&
      buildNumber == other.buildNumber;

  @override
  int get hashCode => Object.hash(major, minor, patch, buildNumber);

  @override
  String toString() => fullLabel;
}

bool isTrustedGitHubDownloadUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'https') return false;
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return false;
  return host == 'github.com' ||
      host == 'api.github.com' ||
      host.endsWith('.githubusercontent.com');
}

@immutable
class AppRelease {
  const AppRelease({
    required this.tagName,
    required this.version,
    required this.title,
    required this.notes,
    required this.apkName,
    required this.apkDownloadUrl,
    required this.apkSizeBytes,
    this.publishedAt,
    this.htmlUrl,
  });

  final String tagName;
  final AppVersion version;
  final String title;
  final String notes;
  final String apkName;
  final Uri apkDownloadUrl;
  final int apkSizeBytes;
  final DateTime? publishedAt;
  final Uri? htmlUrl;

  static AppRelease? fromGitHubJson(Map<String, dynamic> json) {
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final tagName = (json['tag_name'] as String?)?.trim() ?? '';
    final version = AppVersion.tryParse(tagName);
    if (version == null) return null;

    final rawAssets = json['assets'];
    if (rawAssets is! List) return null;

    Map<String, dynamic>? chosen;
    for (final entry in rawAssets) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final name = (map['name'] as String?)?.trim() ?? '';
      final rawUrl = (map['browser_download_url'] as String?)?.trim() ?? '';
      final uri = Uri.tryParse(rawUrl);
      if (!name.toLowerCase().endsWith('.apk') ||
          uri == null ||
          !isTrustedGitHubDownloadUri(uri)) {
        continue;
      }
      chosen ??= map;
      final lower = name.toLowerCase();
      if (lower.contains('growvia') && !lower.contains('debug')) {
        chosen = map;
        break;
      }
    }

    if (chosen == null) return null;

    final apkName = (chosen['name'] as String).trim();
    final apkUrl = Uri.parse((chosen['browser_download_url'] as String).trim());
    final rawSize = chosen['size'];
    final apkSize = rawSize is num ? rawSize.toInt() : 0;
    final title = (json['name'] as String?)?.trim();
    final notes = (json['body'] as String?)?.trim() ?? '';
    final publishedRaw = (json['published_at'] as String?)?.trim();
    final htmlRaw = (json['html_url'] as String?)?.trim();

    return AppRelease(
      tagName: tagName,
      version: version,
      title: (title == null || title.isEmpty) ? 'Growvia Mobile $tagName' : title,
      notes: notes,
      apkName: apkName,
      apkDownloadUrl: apkUrl,
      apkSizeBytes: apkSize,
      publishedAt: publishedRaw == null ? null : DateTime.tryParse(publishedRaw),
      htmlUrl: htmlRaw == null ? null : Uri.tryParse(htmlRaw),
    );
  }
}

abstract class AppUpdatePlatform {
  Future<AppVersion> getInstalledVersion();
  Future<String?> getUpdateCacheDir();
  Future<bool> canInstallPackages();
  Future<void> openInstallPermissionSettings();
  Future<void> installApk(String filePath);
}

class MethodChannelAppUpdatePlatform implements AppUpdatePlatform {
  const MethodChannelAppUpdatePlatform();

  static const MethodChannel _channel = MethodChannel(
    'com.growvia.mobile/updater',
  );

  static const AppVersion _fallback = AppVersion(
    major: 0,
    minor: 1,
    patch: 0,
    buildNumber: kFallbackBuildNumber,
  );

  @override
  Future<AppVersion> getInstalledVersion() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'getAppVersion',
      );
      if (data == null) return _fallback;
      final versionStr = (data['version'] as String?) ?? kFallbackAppVersion;
      final build = (data['buildNumber'] as num?)?.toInt() ?? kFallbackBuildNumber;
      return AppVersion.tryParse(versionStr, buildNumberOverride: build) ??
          _fallback;
    } on MissingPluginException {
      return _fallback;
    } on PlatformException {
      return _fallback;
    } on FlutterError {
      return _fallback;
    }
  }

  @override
  Future<String?> getUpdateCacheDir() async {
    try {
      return await _channel.invokeMethod<String>('getUpdateCacheDir');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on FlutterError {
      return null;
    }
  }

  @override
  Future<bool> canInstallPackages() async {
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on FlutterError {
      return false;
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallPermissionSettings');
    } on MissingPluginException {
      // Abaikan di luar Android.
    } on FlutterError {
      // Abaikan di test tanpa binding.
    }
  }

  @override
  Future<void> installApk(String filePath) async {
    await _channel.invokeMethod<void>('installApk', {'path': filePath});
  }
}

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  permissionRequired,
  readyToInstall,
  error,
}

class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    required this.client,
    AppUpdatePlatform? platform,
    this.repository = kGrowviaGithubRepo,
  }) : platform = platform ?? const MethodChannelAppUpdatePlatform();

  final http.Client client;
  final AppUpdatePlatform platform;
  final String repository;

  AppVersion installedVersion = const AppVersion(
    major: 0,
    minor: 1,
    patch: 0,
    buildNumber: kFallbackBuildNumber,
  );
  bool _versionLoaded = false;
  AppUpdateStatus status = AppUpdateStatus.idle;
  AppRelease? latestRelease;
  String? errorMessage;
  String? statusMessage;
  String? downloadedApkPath;
  int downloadedBytes = 0;
  int totalBytes = 0;
  bool _bannerDismissed = false;
  bool _disposed = false;
  bool _cancelRequested = false;
  StreamSubscription<List<int>>? _downloadSub;

  double? get progress {
    if (totalBytes <= 0) return null;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  bool get hasUpdate =>
      latestRelease != null &&
      latestRelease!.version.isNewerThan(installedVersion);

  bool get showBanner =>
      !_bannerDismissed &&
      hasUpdate &&
      status != AppUpdateStatus.idle &&
      status != AppUpdateStatus.checking &&
      status != AppUpdateStatus.upToDate;

  Future<void> loadInstalledVersion() async {
    if (_versionLoaded) return;
    final detected = await platform.getInstalledVersion();
    if (_disposed) return;
    installedVersion = detected;
    _versionLoaded = true;
    _notify();
  }

  Future<void> checkForUpdate({bool silent = false}) async {
    if (_disposed ||
        status == AppUpdateStatus.checking ||
        status == AppUpdateStatus.downloading) {
      return;
    }

    await loadInstalledVersion();
    if (_disposed) return;

    if (!silent) {
      status = AppUpdateStatus.checking;
      errorMessage = null;
      statusMessage = 'Memeriksa rilis terbaru di GitHub…';
      _notify();
    }

    final uri = Uri.https(
      'api.github.com',
      '/repos/$repository/releases/latest',
    );

    try {
      final response = await client
          .get(
            uri,
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'GrowviaMobile/${installedVersion.versionName}',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (_disposed) return;

      if (response.statusCode == 404) {
        if (silent) return;
        status = AppUpdateStatus.upToDate;
        statusMessage = 'Belum ada rilis APK yang dipublikasikan di GitHub.';
        errorMessage = null;
        _notify();
        return;
      }

      if (response.statusCode != 200) {
        if (silent) return;
        status = AppUpdateStatus.error;
        errorMessage =
            'Gagal memeriksa pembaruan (HTTP ${response.statusCode}). Coba beberapa saat lagi.';
        _notify();
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        if (silent) return;
        status = AppUpdateStatus.error;
        errorMessage = 'Format data rilis GitHub tidak dikenali.';
        _notify();
        return;
      }

      final release = AppRelease.fromGitHubJson(decoded);
      if (release == null) {
        if (silent) return;
        status = AppUpdateStatus.upToDate;
        statusMessage = 'Rilis terbaru belum menyertakan berkas APK Android.';
        errorMessage = null;
        _notify();
        return;
      }

      latestRelease = release;
      errorMessage = null;

      if (release.version.isNewerThan(installedVersion)) {
        _bannerDismissed = false;
        status = AppUpdateStatus.available;
        statusMessage = 'Versi ${release.version.label} siap dipasang.';
      } else {
        status = AppUpdateStatus.upToDate;
        statusMessage =
            'Aplikasi sudah versi terbaru (${installedVersion.label}).';
      }
      _notify();
    } catch (_) {
      if (_disposed || silent) return;
      status = AppUpdateStatus.error;
      errorMessage =
          'Tidak dapat terhubung ke GitHub. Periksa koneksi internet perangkat.';
      _notify();
    }
  }

  Future<void> downloadAndInstall() async {
    final release = latestRelease;
    if (_disposed ||
        release == null ||
        status == AppUpdateStatus.downloading) {
      return;
    }

    if (!isTrustedGitHubDownloadUri(release.apkDownloadUrl)) {
      status = AppUpdateStatus.error;
      errorMessage = 'Tautan unduhan pembaruan tidak berasal dari HTTPS GitHub.';
      _notify();
      return;
    }

    final cacheDirPath = await platform.getUpdateCacheDir();
    if (_disposed) return;
    if (cacheDirPath == null || cacheDirPath.isEmpty) {
      status = AppUpdateStatus.error;
      errorMessage =
          'Pemasangan otomatis hanya didukung di perangkat Android.';
      _notify();
      return;
    }

    _cancelRequested = false;
    status = AppUpdateStatus.downloading;
    errorMessage = null;
    statusMessage = 'Mengunduh ${release.apkName}…';
    downloadedBytes = 0;
    totalBytes = release.apkSizeBytes;
    _notify();

    final safeTag = release.tagName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final finalFile = File('$cacheDirPath${Platform.pathSeparator}growvia-$safeTag.apk');
    final partFile = File('${finalFile.path}.part');
    IOSink? sink;

    try {
      final request = http.Request('GET', release.apkDownloadUrl)
        ..headers['User-Agent'] = 'GrowviaMobile/${installedVersion.versionName}'
        ..headers['Accept'] = 'application/octet-stream';

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (_disposed || _cancelRequested) {
        await _cleanupFile(partFile);
        return;
      }

      final resolvedUri = response.request?.url;
      if (resolvedUri != null && resolvedUri.scheme.toLowerCase() != 'https') {
        throw const FormatException('Redirect unduhan non-HTTPS ditolak.');
      }

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      if ((response.contentLength ?? 0) > 0) {
        totalBytes = response.contentLength!;
      }

      await Directory(cacheDirPath).create(recursive: true);
      if (await partFile.exists()) {
        await partFile.delete();
      }
      sink = partFile.openWrite();

      final headerBytes = <int>[];
      var lastNotifyMs = 0;
      final completer = Completer<void>();

      _downloadSub = response.stream.listen(
        (chunk) {
          if (_cancelRequested || _disposed) return;
          if (headerBytes.length < 2) {
            final need = 2 - headerBytes.length;
            headerBytes.addAll(chunk.take(need));
          }
          sink?.add(chunk);
          downloadedBytes += chunk.length;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - lastNotifyMs >= 120) {
            lastNotifyMs = nowMs;
            _notify();
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object err, StackTrace st) {
          if (!completer.isCompleted) completer.completeError(err, st);
        },
        cancelOnError: true,
      );

      await completer.future;
      await _downloadSub?.cancel();
      _downloadSub = null;
      await sink.flush();
      await sink.close();
      sink = null;

      if (_cancelRequested || _disposed) {
        await _cleanupFile(partFile);
        return;
      }

      // Berkas APK adalah arsip ZIP yang selalu diawali magic bytes 'PK' (0x50 0x4B).
      if (downloadedBytes < 100 ||
          headerBytes.length < 2 ||
          headerBytes[0] != 0x50 ||
          headerBytes[1] != 0x4B) {
        await _cleanupFile(partFile);
        throw const FormatException('Berkas APK rusak atau tidak valid.');
      }

      await _purgeOlderApks(cacheDirPath, keepPath: finalFile.path);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await partFile.rename(finalFile.path);
      downloadedApkPath = finalFile.path;

      await _triggerInstall(finalFile.path);
    } catch (error) {
      try {
        await _downloadSub?.cancel();
      } catch (_) {}
      _downloadSub = null;
      try {
        await sink?.close();
      } catch (_) {}
      await _cleanupFile(partFile);

      if (_disposed || _cancelRequested) return;
      status = AppUpdateStatus.error;
      errorMessage = error is FormatException
          ? error.message
          : 'Gagal mengunduh pembaruan. Coba ulangi beberapa saat lagi.';
      _notify();
    }
  }

  Future<void> _triggerInstall(String apkPath) async {
    final allowed = await platform.canInstallPackages();
    if (_disposed) return;

    if (!allowed) {
      status = AppUpdateStatus.permissionRequired;
      statusMessage =
          'Aktifkan izin "Pasang aplikasi tidak dikenal" untuk Growvia, lalu kembali ke layar ini.';
      errorMessage = null;
      _notify();
      return;
    }

    status = AppUpdateStatus.readyToInstall;
    statusMessage = 'Membuka pemasang pembaruan Android…';
    errorMessage = null;
    _notify();

    try {
      await platform.installApk(apkPath);
    } catch (_) {
      if (_disposed) return;
      status = AppUpdateStatus.error;
      errorMessage =
          'Tidak dapat membuka pemasang APK. Pastikan izin pemasangan aktif.';
      _notify();
    }
  }

  Future<void> openInstallSettings() async {
    await platform.openInstallPermissionSettings();
  }

  Future<void> installDownloaded() async {
    final path = downloadedApkPath;
    if (_disposed || path == null || !await File(path).exists()) {
      await downloadAndInstall();
      return;
    }
    await _triggerInstall(path);
  }

  void cancelDownload() {
    if (status != AppUpdateStatus.downloading) return;
    _cancelRequested = true;
    unawaited(_downloadSub?.cancel());
    _downloadSub = null;
    status = latestRelease != null
        ? AppUpdateStatus.available
        : AppUpdateStatus.idle;
    statusMessage = 'Unduhan dibatalkan.';
    downloadedBytes = 0;
    _notify();
  }

  void dismissBanner() {
    _bannerDismissed = true;
    _notify();
  }

  Future<void> _cleanupFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _purgeOlderApks(String dirPath, {required String keepPath}) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is File &&
            entity.path != keepPath &&
            entity.path.endsWith('.apk')) {
          await _cleanupFile(entity);
        }
      }
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRequested = true;
    unawaited(_downloadSub?.cancel());
    _downloadSub = null;
    super.dispose();
  }
}

String formatFileSize(int bytes) {
  if (bytes <= 0) return 'Ukuran tidak diketahui';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
