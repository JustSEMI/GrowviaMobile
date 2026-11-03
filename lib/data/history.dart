import 'reading.dart';

String readingsToCsv(List<Reading> readings) {
  if (readings.isEmpty) throw StateError('Belum ada data untuk diekspor.');
  String cell(String value) {
    final safe = RegExp(r'^[\s]*[=+@-]').hasMatch(value) ? "'$value" : value;
    return safe.contains(RegExp('[,"\r\n]'))
        ? '"${safe.replaceAll('"', '""')}"'
        : safe;
  }

  final rows = readings.map(
    (reading) => [
      reading.recordedAt.toUtc().toIso8601String(),
      cell(reading.node),
      cell(reading.metric),
      reading.value.toString(),
      cell(reading.unit),
    ].join(','),
  );
  return '\ufeffwaktu_utc,node,parameter,nilai,satuan\r\n${rows.join('\r\n')}\r\n';
}
