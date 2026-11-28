import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/core/app_controller.dart';
import 'package:growvia_mobile/data/mqtt_service.dart';
import 'package:growvia_mobile/data/reading.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _stamp = '2026-11-14T09:00:00.000Z';

Reading _reading(
  String metric,
  double value, {
  String node = 'node1',
  int minutes = 0,
}) => Reading(
  id: value.toInt(),
  node: node,
  metric: metric,
  value: value,
  unit: kMetricUnits[metric] ?? '',
  recordedAt: DateTime.utc(2026, 11, 14, 9, minutes),
);

void main() {
  group('parseMqttUrl', () {
    test('accepts wss and ws and fills default ports', () {
      final secure = parseMqttUrl('wss://mqtt.justsemi.my.id/mqtt');
      expect(secure.host, 'mqtt.justsemi.my.id');
      expect(secure.port, 443);
      expect(secure.secure, isTrue);
      final plain = parseMqttUrl('ws://127.0.0.1:8083/mqtt');
      expect(plain.host, '127.0.0.1');
      expect(plain.port, 8083);
      expect(plain.secure, isFalse);
    });

    test('rejects other schemes and garbage', () {
      expect(() => parseMqttUrl('mqtt://x/mqtt'), throwsFormatException);
      expect(() => parseMqttUrl('bukan alamat'), throwsFormatException);
    });
  });

  group('readingsFromLiveMessage', () {
    test('parses a device1 payload into readings with matching units', () {
      final readings = readingsFromLiveMessage(
        'growvia/node1/data',
        '{"temperature":29.7,"humidity":72.1,"temperature2":28.4,'
        '"humidity2":70.2,"light":41.3,"co2":615,"fan1":1}',
        recordedAt: DateTime.parse(_stamp),
      );
      expect(readings, hasLength(7));
      expect(readings.every((r) => r.node == 'node1'), isTrue);
      expect(readings.every((r) => r.recordedAt.isUtc), isTrue);
      final byMetric = {for (final r in readings) r.metric: r};
      expect(byMetric['temperature']!.value, 29.7);
      expect(byMetric['temperature']!.unit, '°C');
      expect(byMetric['humidity']!.unit, '%');
      expect(byMetric['light']!.unit, 'klux');
      expect(byMetric['co2']!.value, 615);
      expect(byMetric['co2']!.unit, 'ppm');
      expect(byMetric['fan1']!.value, 1);
      expect(byMetric['fan1']!.unit, 'state');
    });

    test('parses a device2 soil payload', () {
      final readings = readingsFromLiveMessage(
        'growvia/node2/data',
        '{"soil_moisture":38.5,"soil_moisture2":40.1,"soil_moisture3":36.2,'
        '"soil_temperature":27.9,"water_level":82,"pump":1}',
        recordedAt: DateTime.parse(_stamp),
      );
      expect(readings, hasLength(6));
      expect(readings.every((r) => r.node == 'node2'), isTrue);
      expect(
        readings.map((r) => r.metric),
        containsAll(['soil_moisture', 'water_level', 'pump']),
      );
    });

    test('rejects foreign topics, broken json, and non numeric values', () {
      expect(
        readingsFromLiveMessage('growvia/node3/data', '{"temperature":1}'),
        isEmpty,
      );
      expect(readingsFromLiveMessage('growvia/status', '{"temperature":1}'), isEmpty);
      expect(readingsFromLiveMessage('growvia/node1/data', 'bukan json'), isEmpty);
      expect(
        readingsFromLiveMessage('growvia/node1/data', '["temperature"]'),
        isEmpty,
      );
      expect(
        readingsFromLiveMessage('growvia/node1/data', '{"temperature":"panas"}'),
        isEmpty,
      );
      expect(
        readingsFromLiveMessage('growvia/node1/data', '{"unknown_metric":5}'),
        isEmpty,
      );
    });
  });

  group('AppController.applyLiveReadings', () {
    test('merges live readings newest first and notifies', () {
      final controller = AppController(
        client: MockClient((request) async => http.Response('{}', 200)),
      );
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified++);
      controller.readings = [_reading('temperature', 27.0, minutes: 0)];
      controller.applyLiveReadings([
        _reading('temperature', 29.7, minutes: 5),
      ]);
      expect(controller.readings.first.value, 29.7);
      expect(controller.readings, hasLength(2));
      expect(notified, greaterThanOrEqualTo(1));
    });

    test('drops duplicate timestamps per node and metric', () {
      final controller = AppController(
        client: MockClient((request) async => http.Response('{}', 200)),
      );
      addTearDown(controller.dispose);
      controller.applyLiveReadings([_reading('temperature', 29.7)]);
      controller.applyLiveReadings([_reading('temperature', 30.2)]);
      // Timestamp sama persis: yang terbaru menang, tidak bertumpuk.
      expect(controller.readings, hasLength(1));
      expect(controller.readings.first.value, 30.2);
    });

    test('caps stored history per metric', () {
      final controller = AppController(
        client: MockClient((request) async => http.Response('{}', 200)),
      );
      addTearDown(controller.dispose);
      final burst = List.generate(130, (index) {
        return Reading(
          id: index,
          node: 'node1',
          metric: 'temperature',
          value: index.toDouble(),
          unit: '°C',
          recordedAt: DateTime.utc(2026, 11, 14, 9, index),
        );
      });
      controller.applyLiveReadings(burst);
      expect(controller.readings, hasLength(120));
      // Yang tertua di buang, 120 terbaru tersisa.
      expect(controller.readings.first.value, 129);
      expect(controller.readings.last.value, 10);
    });

    test('startLive does nothing without a factory and stops cleanly', () {
      final controller = AppController(
        client: MockClient((request) async => http.Response('{}', 200)),
      );
      addTearDown(controller.dispose);
      controller.liveConnected = true;
      controller.startLive();
      // Tanpa pabrik (test): tidak ada sambungan, status tetap apa adanya.
      expect(controller.liveConnected, isTrue);
      controller.stopLive();
      expect(controller.liveConnected, isFalse);
      expect(controller.liveError, isNull);
    });
  });
}
