import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/core/preferences.dart';
import 'package:growvia_mobile/core/theme.dart';
import 'package:growvia_mobile/data/app_updater.dart';
import 'package:growvia_mobile/features/settings_page.dart';
import 'package:growvia_mobile/ui/update_components.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUpdatePlatform implements AppUpdatePlatform {
  _FakeUpdatePlatform({
    this.installed = const AppVersion(major: 0, minor: 1, patch: 0, buildNumber: 1),
    this.cacheDir,
    this.canInstall = true,
  });

  AppVersion installed;
  String? cacheDir;
  bool canInstall;
  int openSettingsCalls = 0;
  final List<String> installedPaths = [];

  @override
  Future<AppVersion> getInstalledVersion() async => installed;

  @override
  Future<String?> getUpdateCacheDir() async => cacheDir;

  @override
  Future<bool> canInstallPackages() async => canInstall;

  @override
  Future<void> openInstallPermissionSettings() async {
    openSettingsCalls++;
  }

  @override
  Future<void> installApk(String filePath) async {
    installedPaths.add(filePath);
  }
}

Map<String, dynamic> _releaseJson({
  String tag = 'v0.2.0',
  String apkName = 'growvia-mobile-v0.2.0.apk',
  String downloadUrl =
      'https://github.com/JustSEMI/GrowviaMobile/releases/download/v0.2.0/growvia-mobile-v0.2.0.apk',
  int size = 512,
  bool draft = false,
  bool prerelease = false,
  String body = 'Perbaikan kontrol kipas dan pembaruan otomatis.',
}) => {
  'tag_name': tag,
  'name': 'Growvia Mobile $tag',
  'body': body,
  'draft': draft,
  'prerelease': prerelease,
  'published_at': '2026-11-27T00:00:00Z',
  'html_url': 'https://github.com/JustSEMI/GrowviaMobile/releases/tag/$tag',
  'assets': [
    {
      'name': apkName,
      'browser_download_url': downloadUrl,
      'size': size,
    },
  ],
};

List<int> _fakeApkBytes([int length = 256]) => [
  0x50,
  0x4B,
  0x03,
  0x04,
  ...List<int>.filled(length - 4, 0x41),
];

void main() {
  test('AppVersion parses semantic versions and compares accurately', () {
    final v010 = AppVersion.tryParse('0.1.0+1')!;
    final v011 = AppVersion.tryParse('v0.1.1')!;
    final v010b2 = AppVersion.tryParse('v0.1.0+2')!;
    final v100 = AppVersion.tryParse('v1.0.0')!;

    expect(v011.isNewerThan(v010), isTrue);
    expect(v010.isNewerThan(v011), isFalse);
    expect(v010b2.isNewerThan(v010), isTrue);
    expect(v100.isNewerThan(v011), isTrue);
    expect(v010.isNewerThan(v010), isFalse);
    expect(AppVersion.tryParse('not-a-version'), isNull);
  });

  test('AppRelease accepts only trusted HTTPS GitHub APK URLs and skips drafts', () {
    expect(
      AppRelease.fromGitHubJson(_releaseJson(draft: true)),
      isNull,
    );
    expect(
      AppRelease.fromGitHubJson(_releaseJson(prerelease: true)),
      isNull,
    );
    expect(
      AppRelease.fromGitHubJson(
        _releaseJson(
          downloadUrl: 'http://github.com/JustSEMI/GrowviaMobile/releases/download/v0.2.0/app.apk',
        ),
      ),
      isNull,
    );
    expect(
      AppRelease.fromGitHubJson(
        _releaseJson(downloadUrl: 'https://evil.example.com/growvia.apk'),
      ),
      isNull,
    );

    final valid = AppRelease.fromGitHubJson(_releaseJson());
    expect(valid, isNotNull);
    expect(valid!.version.label, 'v0.2.0');
    expect(valid.apkName, 'growvia-mobile-v0.2.0.apk');
  });

  test('AppUpdateController checks GitHub, downloads APK, verifies PK magic, and launches installer', () async {
    final tempDir = await Directory.systemTemp.createTemp('growvia-upd-test-');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    final platform = _FakeUpdatePlatform(cacheDir: tempDir.path, canInstall: true);
    final client = MockClient.streaming((request, bodyStream) async {
      if (request.url.host == 'api.github.com') {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(_releaseJson()))),
          200,
        );
      }
      final bytes = _fakeApkBytes(300);
      return http.StreamedResponse(
        Stream.value(bytes),
        200,
        contentLength: bytes.length,
        request: request,
      );
    });

    final updater = AppUpdateController(client: client, platform: platform);
    addTearDown(updater.dispose);

    await updater.checkForUpdate(silent: false);
    expect(updater.status, AppUpdateStatus.available);
    expect(updater.hasUpdate, isTrue);
    expect(updater.showBanner, isTrue);

    await updater.downloadAndInstall();
    expect(updater.status, AppUpdateStatus.readyToInstall);
    expect(platform.installedPaths, hasLength(1));
    expect(await File(platform.installedPaths.single).exists(), isTrue);
  });

  test('AppUpdateController prompts for install permission then installs cached APK once allowed', () async {
    final tempDir = await Directory.systemTemp.createTemp('growvia-upd-perm-');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    final platform = _FakeUpdatePlatform(cacheDir: tempDir.path, canInstall: false);
    var downloadCalls = 0;
    final client = MockClient.streaming((request, bodyStream) async {
      if (request.url.host == 'api.github.com') {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(_releaseJson()))),
          200,
        );
      }
      downloadCalls++;
      final bytes = _fakeApkBytes(200);
      return http.StreamedResponse(
        Stream.value(bytes),
        200,
        contentLength: bytes.length,
        request: request,
      );
    });

    final updater = AppUpdateController(client: client, platform: platform);
    addTearDown(updater.dispose);

    await updater.checkForUpdate();
    await updater.downloadAndInstall();

    expect(updater.status, AppUpdateStatus.permissionRequired);
    expect(platform.installedPaths, isEmpty);
    expect(downloadCalls, 1);

    await updater.openInstallSettings();
    expect(platform.openSettingsCalls, 1);

    platform.canInstall = true;
    await updater.installDownloaded();
    expect(updater.status, AppUpdateStatus.readyToInstall);
    expect(platform.installedPaths, hasLength(1));
    expect(downloadCalls, 1);
  });

  test('AppUpdateController rejects corrupt non-APK downloads safely', () async {
    final tempDir = await Directory.systemTemp.createTemp('growvia-upd-bad-');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    final platform = _FakeUpdatePlatform(cacheDir: tempDir.path, canInstall: true);
    final client = MockClient.streaming((request, bodyStream) async {
      if (request.url.host == 'api.github.com') {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(_releaseJson()))),
          200,
        );
      }
      return http.StreamedResponse(
        Stream.value(utf8.encode('<html>Not an APK</html>')),
        200,
        request: request,
      );
    });

    final updater = AppUpdateController(client: client, platform: platform);
    addTearDown(updater.dispose);

    await updater.checkForUpdate();
    await updater.downloadAndInstall();

    expect(updater.status, AppUpdateStatus.error);
    expect(platform.installedPaths, isEmpty);
  });

  test('AppUpdateController reports upToDate when installed version matches latest release', () async {
    final platform = _FakeUpdatePlatform(
      installed: const AppVersion(major: 0, minor: 2, patch: 0, buildNumber: 1),
    );
    final client = MockClient(
      (_) async => http.Response(jsonEncode(_releaseJson(tag: 'v0.2.0')), 200),
    );
    final updater = AppUpdateController(client: client, platform: platform);
    addTearDown(updater.dispose);

    await updater.checkForUpdate(silent: false);
    expect(updater.status, AppUpdateStatus.upToDate);
    expect(updater.hasUpdate, isFalse);
    expect(updater.showBanner, isFalse);
  });

  test('AppUpdateController handles 404 quietly when silent and explains when manual', () async {
    final platform = _FakeUpdatePlatform();
    final client = MockClient((_) async => http.Response('Not Found', 404));
    final updater = AppUpdateController(client: client, platform: platform);
    addTearDown(updater.dispose);

    await updater.checkForUpdate(silent: true);
    expect(updater.status, AppUpdateStatus.idle);
    expect(updater.errorMessage, isNull);

    await updater.checkForUpdate(silent: false);
    expect(updater.status, AppUpdateStatus.upToDate);
    expect(updater.statusMessage, contains('Belum ada rilis APK'));
  });

  testWidgets('SettingsPage and AppUpdateSheet render update flow cleanly at scale 2.0', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppPreferences();
    await prefs.load();

    final platform = _FakeUpdatePlatform();
    final client = MockClient(
      (_) async => http.Response(jsonEncode(_releaseJson()), 200),
    );
    final updater = AppUpdateController(client: client, platform: platform);
    addTearDown(updater.dispose);
    addTearDown(prefs.dispose);

    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: GrowviaTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2.0),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              ListenableBuilder(
                listenable: updater,
                builder: (context, _) => AppUpdateBanner(
                  updater: updater,
                  onOpenUpdate: () => showAppUpdateSheet(context, updater),
                ),
              ),
              Expanded(
                child: SettingsPage(preferences: prefs, updater: updater),
              ),
            ],
          ),
        ),
      ),
    );

    final actionFinder = find.byKey(const Key('app-update-action'));
    await tester.scrollUntilVisible(
      actionFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cek pembaruan aplikasi'), findsOneWidget);

    await tester.tap(actionFinder);
    await tester.pumpAndSettle();

    expect(find.text('Perbarui ke v0.2.0'), findsOneWidget);
    expect(find.text('Pembaruan v0.2.0 tersedia'), findsOneWidget);

    await tester.tap(actionFinder);
    await tester.pumpAndSettle();

    expect(find.text('Pembaruan aplikasi'), findsOneWidget);
    final downloadBtn = find.text('Unduh & pasang v0.2.0');
    await tester.scrollUntilVisible(
      downloadBtn,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(downloadBtn, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
