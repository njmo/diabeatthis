import '../../../../core/domain/model/glucose.dart';

class LocalGlucoseEvent {
  const LocalGlucoseEvent({required this.data});

  final Glucose data;

  factory LocalGlucoseEvent.fromJson(Map<String, dynamic> json) {
    final timestamp = _intValue(json['timestamp']);
    final sgv = _intValue(json['sgv']);
    final source = GlucoseSource.fromStorage(json['source'] as String?);
    final direction = json['direction'];
    final externalId = json['externalId'];

    if (timestamp == null || timestamp <= 0 || sgv == null || sgv <= 0) {
      throw FormatException('Invalid local glucose event payload: $json');
    }

    return LocalGlucoseEvent(
      data: Glucose(
        externalId: externalId is String ? externalId : null,
        source: source,
        date: DateTime.fromMillisecondsSinceEpoch(timestamp),
        sgv: sgv,
        direction: direction is String && direction.isNotEmpty
            ? direction
            : 'Flat',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'externalId': data.externalId,
      'source': data.source.storageValue,
      'timestamp': data.date.millisecondsSinceEpoch,
      'sgv': data.sgv,
      'direction': data.direction,
    };
  }

  static int? _intValue(Object? value) {
    return switch (value) {
      int() => value,
      double() => value.round(),
      String() => int.tryParse(value),
      _ => null,
    };
  }
}
