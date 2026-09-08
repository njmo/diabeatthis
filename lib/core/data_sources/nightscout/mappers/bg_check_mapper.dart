import '../../../domain/model/bg_check.dart';
import '../../../domain/model/glucose.dart';

/// Nightscout treatments use ISO timestamps and may encode glucose as a string.
BgCheck? parseBgCheck(Map<String, dynamic> json) {
  final id = json['_id']?.toString();
  final date = DateTime.tryParse(json['created_at']?.toString() ?? '');
  if (id == null || id.isEmpty || date == null) return null;
  final valid = json['isValid'] != false;
  final value = double.tryParse(json['glucose']?.toString() ?? '');
  final units = (json['units']?.toString() ?? 'mg/dl').trim().toLowerCase();
  if (valid &&
      (value == null ||
          !value.isFinite ||
          value <= 0 ||
          !['mg/dl', 'mmol/l'].contains(units))) {
    return null;
  }
  final method = json['glucoseType']?.toString().toLowerCase();
  final type = switch (method) {
    'finger' => GlucoseType.finger,
    'sensor' => GlucoseType.sensor,
    'manual' => GlucoseType.manual,
    _ => GlucoseType.other,
  };
  return BgCheck(
    Glucose(
      externalId: id,
      source: GlucoseSource.cloud,
      date: date.toLocal(),
      sgv: valid ? (value! * (units == 'mmol/l' ? 18 : 1)).round() : 0,
      direction: '',
      type: type,
      notes: json['notes']?.toString(),
    ),
    isValid: valid,
  );
}
