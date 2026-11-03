import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/data/reading.dart';
import 'package:growvia_mobile/ui/charts.dart';
import 'package:growvia_mobile/core/theme.dart';

void main() {
  testWidgets(
    'gauge shows valid supplied moisture but never substitutes zero for no data',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: GrowviaTheme.light(),
          home: const Scaffold(body: MoistureGauge(reading: null)),
        ),
      );
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          theme: GrowviaTheme.light(),
          home: Scaffold(
            body: MoistureGauge(
              reading: Reading(
                id: 1,
                node: 'node2',
                metric: 'soil_moisture',
                value: 54,
                unit: '%',
                recordedAt: DateTime.utc(2026, 9, 16),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('54%'), findsOneWidget);
      expect(find.textContaining('bukan realtime'), findsOneWidget);
    },
  );

  testWidgets('chart explains one point and exposes its observed range', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GrowviaTheme.light(),
        home: Scaffold(
          body: ReadingChart(
            readings: [
              Reading(
                id: 1,
                node: 'node1',
                metric: 'temperature',
                value: 26.5,
                unit: '°C',
                recordedAt: DateTime.utc(2026, 9, 16),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Satu titik belum menunjukkan tren.'), findsOneWidget);
    expect(find.textContaining('Rentang data: 26.5–26.5 °C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
