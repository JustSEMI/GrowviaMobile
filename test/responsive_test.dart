import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growvia_mobile/main.dart';

const base = 'https://growvia.example/api/v1';

http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

MockClient loginClient() {
  const user = {
    'id': 1,
    'name': 'Pengelola Kebun Uji',
    'email': 'kebun@example.test',
    'role': 'user',
    'is_active': true,
  };
  return MockClient((request) async {
    if (request.url.path.endsWith('/auth/login')) {
      return jsonResponse({'token': 'test-token', 'user': user});
    }
    if (request.url.path.endsWith('/auth/me')) {
      return jsonResponse({'user': user});
    }
    if (request.url.path.endsWith('/workspace')) {
      return jsonResponse({
        'settings': {'th_suhu_min': '25', 'th_suhu_max': '30'},
        'counts': null,
        'recent_activities': [],
        'telemetry_available': false,
      });
    }
    return jsonResponse({'data': []});
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'growvia.api_url': base});
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(800, 1100),
    const Size(1100, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('login and shell are usable at $size with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final client = loginClient();
        addTearDown(client.close);
        await tester.pumpWidget(MainApp(client: client));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byKey(const Key('login-email')),
          'kebun@example.test',
        );
        await tester.enterText(
          find.byKey(const Key('login-password')),
          'rahasia',
        );
        await tester.ensureVisible(find.text('Masuk'));
        await tester.tap(find.text('Masuk'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final tab in ['Riwayat', 'Edukasi', 'Pengaturan']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$tab at $size / $scale',
          );
        }
      });
    }
  }
}