class Reading {
  const Reading({
    required this.id,
    required this.node,
    required this.metric,
    required this.value,
    required this.unit,
    required this.recordedAt,
  });

  final int id;
  final String node;
  final String metric;
  final double value;
  final String unit;
  final DateTime recordedAt;

  factory Reading.fromJson(Map<String, dynamic> json) {
    final number = json['value'];
    final timestamp = json['recorded_at'];
    final date = timestamp is String ? DateTime.tryParse(timestamp) : null;
    if (json['id'] is! int ||
        json['node'] is! String ||
        json['metric'] is! String ||
        number is! num ||
        !number.isFinite ||
        json['unit'] is! String ||
        date == null ||
        !date.isUtc) {
      throw const FormatException(
        'Format pembacaan tidak valid. Timestamp harus menyertakan zona waktu.',
      );
    }
    return Reading(
      id: json['id'] as int,
      node: json['node'] as String,
      metric: json['metric'] as String,
      value: number.toDouble(),
      unit: json['unit'] as String,
      recordedAt: date.toUtc(),
    );
  }

  String get label => switch (metric) {
    'temperature' => 'Suhu udara',
    'humidity' => 'Kelembapan udara',
    'light' => 'Intensitas cahaya',
    'co2' => 'Kadar CO2',
    'soil_moisture' => 'Kelembapan tanah',
    'soil_temperature' => 'Suhu tanah',
    'water_level' => 'Isi tandon',
    'pump' => 'Status pompa',
    _ => metric,
  };
}
