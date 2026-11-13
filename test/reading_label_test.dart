import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/data/reading.dart';

Reading reading(String metric, {String unit = '%'}) => Reading(
  id: 1,
  node: 'node1',
  metric: metric,
  value: 1,
  unit: unit,
  recordedAt: DateTime.utc(2026, 9, 16),
);

void main() {
  // Every metric the dashboard and node detail pages render must have an
  // Indonesian label. Falling through to the raw identifier would show
  // "light" or "soil_temperature" to a farmer reading the app.
  test('every metric rendered by the UI has an Indonesian label', () {
    const expected = {
      'temperature': 'Suhu udara',
      'temperature2': 'Suhu udara 2',
      'humidity': 'Kelembapan udara',
      'humidity2': 'Kelembapan udara 2',
      'light': 'Intensitas cahaya',
      'co2': 'Kadar CO2',
      'soil_moisture': 'Kelembapan tanah',
      'soil_moisture2': 'Kelembapan tanah 2',
      'soil_moisture3': 'Kelembapan tanah 3',
      'soil_temperature': 'Suhu tanah',
      'water_level': 'Isi tandon',
      'pump': 'Status pompa',
      'fan1': 'Kipas 1',
      'fan2': 'Kipas 2',
    };
    for (final entry in expected.entries) {
      expect(
        reading(entry.key).label,
        entry.value,
        reason: 'metric ${entry.key} harus punya label Indonesia',
      );
    }
  });

  test('an unknown metric falls back to its identifier, not a guess', () {
    expect(reading('unmapped_metric').label, 'unmapped_metric');
  });

  test('labels never contain the raw identifier for a known metric', () {
    for (final metric in [
      'temperature',
      'temperature2',
      'humidity',
      'humidity2',
      'light',
      'co2',
      'soil_moisture',
      'soil_moisture2',
      'soil_moisture3',
      'soil_temperature',
      'water_level',
      'pump',
      'fan1',
      'fan2',
    ]) {
      expect(reading(metric).label, isNot(metric));
    }
  });
}
