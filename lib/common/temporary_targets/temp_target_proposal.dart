import 'temp_target_policy.dart';

class TempTargetProposal {
  const TempTargetProposal({
    required this.id,
    required this.entityId,
    required this.targetType,
    required this.target,
    required this.durationMinutes,
    required this.expiresAt,
    required this.source,
    this.endsAt,
    this.durationEndsAt,
    this.renewal = false,
    this.coverageGeneration = 0,
  });

  final String id;
  final int entityId;
  final String targetType;
  final int target;
  final int durationMinutes;
  final DateTime expiresAt;
  final DateTime? endsAt;
  final DateTime? durationEndsAt;
  final bool renewal;
  final String source;
  final int coverageGeneration;

  int durationAt(DateTime now) => (durationEndsAt ?? endsAt) == null
      ? durationMinutes
      : TempTargetPolicy.minutesUntil(now, (durationEndsAt ?? endsAt)!);

  bool hasSameEnd(DateTime? end) => endsAt == null
      ? end == null
      : end != null && endsAt!.isAtSameMomentAs(end);

  Map<String, dynamic> toJson() => {
    'id': id,
    'entityId': entityId,
    'targetType': targetType,
    'target': target,
    'durationMinutes': durationMinutes,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'endsAt': endsAt?.toUtc().toIso8601String(),
    'durationEndsAt': durationEndsAt?.toUtc().toIso8601String(),
    'renewal': renewal,
    'source': source,
    'coverageGeneration': coverageGeneration,
  };

  factory TempTargetProposal.fromJson(Map<String, dynamic> json) =>
      TempTargetProposal(
        id: json['id'] as String,
        entityId: json['entityId'] as int,
        targetType: json['targetType'] as String,
        target: json['target'] as int,
        durationMinutes: json['durationMinutes'] as int,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        endsAt: json['endsAt'] == null
            ? null
            : DateTime.parse(json['endsAt'] as String),
        durationEndsAt: json['durationEndsAt'] == null
            ? null
            : DateTime.parse(json['durationEndsAt'] as String),
        renewal: json['renewal'] as bool? ?? false,
        source: json['source'] as String,
        coverageGeneration: json['coverageGeneration'] as int? ?? 0,
      );
}
