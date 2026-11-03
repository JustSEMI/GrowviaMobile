import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only debug references a scoped Android local cleartext config', () {
    final debug = File('android/app/src/debug/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      debug,
      contains('android:networkSecurityConfig="@xml/growvia_local_network"'),
    );
    for (final mode in ['main', 'profile']) {
      final manifest = File('android/app/src/$mode/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, isNot(contains('networkSecurityConfig')));
      expect(manifest, isNot(contains('usesCleartextTraffic="true"')));
      expect(
        File('android/app/src/$mode/res/xml/growvia_local_network.xml')
            .existsSync(),
        isFalse,
      );
    }
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:usesCleartextTraffic="false"'),
    );
    expect(debug, isNot(contains('usesCleartextTraffic="true"')));
  });

  test(
    'debug cleartext exception has exact hosts and no TLS trust overrides',
    () {
      final config = File(
        'android/app/src/debug/res/xml/growvia_local_network.xml',
      ).readAsStringSync();
      expect(
        config,
        contains('<base-config cleartextTrafficPermitted="false"'),
      );
      expect(
        config,
        contains('<domain-config cleartextTrafficPermitted="true"'),
      );
      expect(
        RegExp(r'<domain includeSubdomains="false">([^<]+)</domain>')
            .allMatches(config)
            .map((m) => m.group(1))
            .toSet(),
        {'127.0.0.1', 'localhost', '10.0.2.2'},
      );
      expect(RegExp(r'<domain\s').allMatches(config).length, 3);
      expect(
        RegExp(r'cleartextTrafficPermitted="true"').allMatches(config).length,
        1,
      );
      expect(config, isNot(contains('trust-anchors')));
      expect(config, isNot(contains('debug-overrides')));
    },
  );
}
