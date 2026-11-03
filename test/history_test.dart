import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/data/reading.dart';
import 'package:growvia_mobile/data/history.dart';

void main() {
  final records = [
    Reading(
      id: 1,
      node: 'node1',
      metric: 'temperature',
      value: 26.5,
      unit: '°C',
      recordedAt: DateTime.utc(2026, 9, 16, 10),
    ),
    Reading(
      id: 2,
      node: '=formula',
      metric: 'humidity',
      value: 60,
      unit: '%,"quoted"',
      recordedAt: DateTime.utc(2026, 9, 15, 10),
    ),
  ];

  test(
    'CSV contains only supplied readings and escapes formulas and quotes',
    () {
      final csv = readingsToCsv(records);
      expect(
        csv,
        startsWith('\ufeffwaktu_utc,node,parameter,nilai,satuan\r\n'),
      );
      expect(
        csv,
        contains('2026-09-16T10:00:00.000Z,node1,temperature,26.5,°C'),
      );
      expect(csv, contains("'=formula"));
      expect(csv, contains('"%,""quoted"""'));
      expect(csv.trim().split('\r\n'), hasLength(3));
    },
  );

  test('an empty history does not pretend to export recorded data', () {
    expect(() => readingsToCsv([]), throwsStateError);
  });
}
