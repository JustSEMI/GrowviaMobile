import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/data/api_client.dart';
import 'package:growvia_mobile/data/api_endpoint.dart';

// Also run with --dart-define=dart.vm.product=true and
// --dart-define=dart.vm.profile=true to exercise the compile-time build gate.
void main() {
  test(
    'injected opt-in cannot override build policy (${kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug'})',
    () {
      const policy = ApiEndpoint(allowDebugHttp: true);
      expect(policy.localHttpAllowed, kDebugMode);
      expect(
        policy.defaultBaseUrl,
        kDebugMode
            ? 'http://127.0.0.1:8000/api/v1'
            : ApiEndpoint.productionBaseUrl,
      );
      expect(Uri.parse(ApiEndpoint.productionBaseUrl).scheme, 'https');
      expect(
        const ApiEndpoint(allowDebugHttp: false).validate(
          ApiEndpoint.productionBaseUrl,
        ),
        isNull,
      );
      for (final host in ['127.0.0.1', 'localhost', '10.0.2.2']) {
        final url = 'http://$host:8000/api/v1';
        if (kDebugMode) {
          expect(policy.validate(url), isNull);
        } else {
          expect(policy.validate(url), isNotNull);
          expect(
            () => GrowviaApi(baseUrl: url, allowDebugHttp: true),
            throwsA(isA<ApiException>()),
          );
        }
      }
      final https = GrowviaApi(
        baseUrl: 'https://growvia.example/api/v1',
        allowDebugHttp: true,
      );
      addTearDown(https.close);
      expect(https.base.scheme, 'https');
    },
  );
}
