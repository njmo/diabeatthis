import 'temp_target_treatment.dart';

/// Ownership is retained across restarts and checked against fresh remote data.
class OwnedTempTarget {
  const OwnedTempTarget({
    required this.entityId,
    required this.targetType,
    required this.source,
    required this.startedAt,
    required this.until,
    required this.target,
    required this.durationMinutes,
    this.nightscoutId,
  });

  final int entityId;
  final String targetType;
  final String source;
  final DateTime startedAt;
  final DateTime until;
  final int target;
  final int durationMinutes;
  final String? nightscoutId;

  bool matchesActive(Map<String, dynamic> treatment, DateTime now) {
    if (treatment['eventType'] != 'Temporary Target' ||
        treatment['isValid'] == false) {
      return false;
    }
    final start = TempTargetTreatment.startedAt(treatment);
    final duration = TempTargetTreatment.duration(treatment);
    if (start == null ||
        now.isBefore(start) ||
        !start.add(duration).isAfter(now)) {
      return false;
    }
    return matchesCreated(treatment);
  }

  bool matchesCreated(Map<String, dynamic> treatment) {
    if (treatment['eventType'] != 'Temporary Target') return false;
    if (nightscoutId != null) return treatment['_id'] == nightscoutId;
    final start = TempTargetTreatment.startedAt(treatment);
    return start?.millisecondsSinceEpoch == startedAt.millisecondsSinceEpoch &&
        treatment['enteredBy'] == 'Diabeatthis' &&
        treatment['targetBottom'] == target &&
        treatment['targetTop'] == target &&
        TempTargetTreatment.duration(treatment) ==
            Duration(minutes: durationMinutes);
  }

  OwnedTempTarget withNightscoutId(String? id) => OwnedTempTarget(
    entityId: entityId,
    targetType: targetType,
    source: source,
    startedAt: startedAt,
    until: until,
    target: target,
    durationMinutes: durationMinutes,
    nightscoutId: id,
  );

  Map<String, dynamic> toJson() => {
    'entityId': entityId,
    'targetType': targetType,
    'source': source,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'until': until.toUtc().toIso8601String(),
    'target': target,
    'durationMinutes': durationMinutes,
    'nightscoutId': nightscoutId,
  };

  factory OwnedTempTarget.fromJson(Map<String, dynamic> json) =>
      OwnedTempTarget(
        entityId: json['entityId'] as int,
        targetType: json['targetType'] as String,
        source: json['source'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        until: DateTime.parse(json['until'] as String),
        target: json['target'] as int,
        durationMinutes: json['durationMinutes'] as int,
        nightscoutId: json['nightscoutId'] as String?,
      );
}
