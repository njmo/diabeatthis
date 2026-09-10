import 'dart:convert';

/// AAPS prediction values are mg/dL at five-minute model steps.
class AapsPredictionSnapshot {
  final DateTime calculatedAt;
  final Map<String, List<double>> series;

  AapsPredictionSnapshot(this.calculatedAt, Map<String, List<double>> series)
    : series = Map.unmodifiable(
        series.map(
          (key, value) => MapEntry(key, List<double>.unmodifiable(value)),
        ),
      );

  Map<String, dynamic> toJson() => {
    'timestamp': calculatedAt.toIso8601String(),
    'predBGs': series,
  };

  static AapsPredictionSnapshot? decode(String? encoded) {
    if (encoded == null) return null;
    try {
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      final at = DateTime.parse(json['timestamp'] as String);
      final raw = json['predBGs'] as Map;
      final series = <String, List<double>>{};
      for (final key in ['IOB', 'COB', 'UAM', 'ZT']) {
        final values = raw[key];
        if (values == null) continue;
        if (values is! List || values.length < 2 || values.length > 48) {
          return null;
        }
        final numbers = values.map((v) => (v as num).toDouble()).toList();
        if (numbers.any((v) => !v.isFinite || v <= 0)) return null;
        series[key] = numbers;
      }
      if (series.isEmpty) return null;
      return AapsPredictionSnapshot(at, series);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}
