import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/data/api_client.dart';
import 'package:growvia_mobile/data/api_endpoint.dart';

void main() {
  test('production switch false rejects every local HTTP host', () {
    const policy = ApiEndpoint(allowDebugHttp: false);
    expect(policy.defaultBaseUrl, ApiEndpoint.productionBaseUrl);
    for (final host in ['127.0.0.1', 'localhost', '10.0.2.2']) {
      final url = 'http://$host:8000/api/v1';
      expect(policy.validate(url), isNotNull);
      expect(
        () => GrowviaApi(baseUrl: url, allowDebugHttp: false),
        throwsA(isA<ApiException>()),
      );
    }
  });

  test('HTTPS remains available with production policy', () {
    const policy = ApiEndpoint(allowDebugHttp: false);
    expect(policy.validate('https://growvia.example/api/v1'), isNull);
    final api = GrowviaApi(
      baseUrl: 'https://growvia.example/api/v1/',
      allowDebugHttp: false,
    );
    addTearDown(api.close);
    expect(api.base.toString(), 'https://growvia.example/api/v1/');
  });

  test('settings may explicitly clear endpoint but client may not', () {
    const policy = ApiEndpoint();
    expect(policy.validate('', allowEmpty: true), isNull);
    expect(policy.validate(''), isNotNull);
    expect(policy.isLocalHttp('http://localhost:8000/api/v1'), isTrue);
    expect(policy.isLocalHttp('http://localhost.evil.test/api/v1'), isFalse);
  });

  for (final host in ['127.0.0.1', 'localhost', '10.0.2.2']) {
    test('debug accepts exact local HTTP host $host', () {
      final api = GrowviaApi(baseUrl: 'http://$host:8000/api/v1');
      addTearDown(api.close);
      expect(api.base.toString(), 'http://$host:8000/api/v1/');
    });
  }

  for (final url in [
    'http://example.com/api/v1',
    'http://192.168.1.2:8000/api/v1',
    'http://127.0.0.2/api/v1',
    'http://127.1/api/v1',
    'http://2130706433/api/v1',
    'http://[::1]/api/v1',
    'http://localhost.example.com/api/v1',
    'http://127.0.0.1.example.com/api/v1',
    'http://10.0.2.2.example.com/api/v1',
    'http://localhost./api/v1',
    'http://user:password@localhost/api/v1',
    'http://@localhost/api/v1',
    'http://localhost@evil.test/api/v1',
    'http://local%68ost/api/v1',
    'http://localhost/api/v1?token=secret',
    'http://localhost/api/v1?',
    'http://localhost/api/v1#fragment',
    'http://localhost/api/v1#',
    'http://localhost/api/../v1',
    'http://localhost/api/%2e%2e/v1',
    'http://localhost/api/%252e%252e/v1',
    'http://localhost/api%2f..%2fv1',
    r'http://localhost/api\..\v1',
    'https://server.test/api/../v1',
    'https://server.test/api/%2e%2e/v1',
    'https://server.test/api/%252e%252e/v1',
    'https://server.test/api%5c..%5cv1',
    'https://@server.test/api/v1',
    'https://server.test:0/api/v1',
    'https://server.test:65536/api/v1',
    'https://server.test:/api/v1',
    'https://server.test/api/\nv1',
    'not a URL',
    '',
  ]) {
    test('rejects unsafe endpoint $url', () {
      expect(() => GrowviaApi(baseUrl: url), throwsA(isA<ApiException>()));
    });
  }
}
