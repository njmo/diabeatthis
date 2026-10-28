enum TimelineRelationKind { meal, activity }

class TimelineRelation {
  const TimelineRelation({
    required this.id,
    required this.kind,
    required this.name,
    required this.at,
  });
  final int id;
  final TimelineRelationKind kind;
  final String name;
  final DateTime at;
}
