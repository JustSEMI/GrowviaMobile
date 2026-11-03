import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/core/preferences.dart';
import 'package:growvia_mobile/data/api_endpoint.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'unreadable saved endpoint fails closed instead of using local default',
    () async {
      SharedPreferences.setMockInitialValues({'growvia.api_url': 42});
      final preferences = AppPreferences();
      addTearDown(preferences.dispose);
      await preferences.load();
      expect(preferences.apiUrl, isEmpty);
      expect(preferences.storageError, isNotNull);
    },
  );

  test('preferences reject unsafe endpoints before persisting them', () async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);
    await expectLater(
      preferences.save('http://public.example/api/v1', ThemeMode.dark),
      throwsA(isA<FormatException>()),
    );
    expect(
      (await SharedPreferences.getInstance()).containsKey('growvia.api_url'),
      isFalse,
    );
    expect(preferences.themeMode, ThemeMode.system);
  });

  test('disabled debug policy defaults to production HTTPS', () async {
    final preferences = AppPreferences(allowDebugHttp: false);
    addTearDown(preferences.dispose);
    await preferences.load();
    expect(preferences.apiUrl, ApiEndpoint.productionBaseUrl);
  });

  test('fresh debug preferences default to USB local API', () async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);
    await preferences.load();
    expect(preferences.apiUrl, 'http://127.0.0.1:8000/api/v1');
    expect(
      (await SharedPreferences.getInstance()).containsKey('growvia.api_url'),
      isFalse,
    );
  });

  for (final saved in [
    '',
    'https://growvia.example/api/v1',
    'http://10.0.2.2:8000/api/v1',
  ]) {
    test('saved endpoint is not replaced by debug default: $saved', () async {
      SharedPreferences.setMockInitialValues({'growvia.api_url': saved});
      final preferences = AppPreferences();
      addTearDown(preferences.dispose);
      await preferences.load();
      expect(preferences.apiUrl, saved);
    });
  }

  test(
    'explicitly saved empty URL remains unconfigured after reload',
    () async {
      final preferences = AppPreferences();
      addTearDown(preferences.dispose);
      await preferences.load();
      await preferences.save('', ThemeMode.dark);
      await preferences.load();
      expect(preferences.apiUrl, isEmpty);
      expect(preferences.themeMode, ThemeMode.dark);
    },
  );
}
