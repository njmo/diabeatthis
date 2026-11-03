enum MealSaveEventKind {
  created,
  advisorCreated,
  advisorUpdated,
  updated,
  summarized,
}

class MealSaveEvent {
  const MealSaveEvent({required this.kind, required this.at});
  final MealSaveEventKind kind;
  final DateTime at;
}
