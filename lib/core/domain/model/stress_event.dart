import 'stress_level.dart';

/// Stress recorded manually or supplied by a cloud/watch adapter.
class StressEvent {
  const StressEvent({
    required this.occurredAt,
    required this.source,
    required this.stressLevel,
    this.externalId,
    this.notes,
    this.id,
    this.endedAt,
  });

  final int? id;
  final DateTime occurredAt;
  final DateTime? endedAt;
  final StressLevel stressLevel;
  final String source;
  final String? externalId;
  final String? notes;

  bool hasSameContent(StressEvent other) =>
      source == other.source &&
      externalId == other.externalId &&
      notes == other.notes &&
      occurredAt.isAtSameMomentAs(other.occurredAt) &&
      endedAt?.millisecondsSinceEpoch ==
          other.endedAt?.millisecondsSinceEpoch &&
      stressLevel == other.stressLevel;
}
