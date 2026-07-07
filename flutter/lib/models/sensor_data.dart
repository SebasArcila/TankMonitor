class SensorData {
  final int id;
  final double temperature;
  final double ph;
  final double level;
  final bool pump;
  final DateTime createdAt;

  SensorData({
    required this.id,
    required this.temperature,
    required this.ph,
    required this.level,
    required this.pump,
    required this.createdAt,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['id'] as int,
      temperature: _toDouble(json['temperature']),
      ph: _toDouble(json['ph']),
      level: _toDouble(json['level']),
      pump: json['pump'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.parse(value);
    throw FormatException('No se pudo convertir a double: $value');
  }
}
