import '../../data/models/meal_details_data.dart';
import '../models/meal_save_event.dart';

/// Current sync state has no historical timestamp and is not a timed event.
class BuildMealSaveTimelineUseCase {
  const BuildMealSaveTimelineUseCase();

  List<MealSaveEvent> call(MealDetailsData details) {
    final meal = details.meal;
    final decision = details.advisorDecision;
    final events = <MealSaveEvent>[
      MealSaveEvent(kind: MealSaveEventKind.created, at: meal.createdAt),
      if (meal.updatedAt.isAfter(meal.createdAt))
        MealSaveEvent(kind: MealSaveEventKind.updated, at: meal.updatedAt),
      if (meal.summarizedAt != null)
        MealSaveEvent(
          kind: MealSaveEventKind.summarized,
          at: meal.summarizedAt!,
        ),
      if (decision != null) ...[
        MealSaveEvent(
          kind: MealSaveEventKind.advisorCreated,
          at: decision.createdAt,
        ),
        if (decision.updatedAt.isAfter(decision.createdAt))
          MealSaveEvent(
            kind: MealSaveEventKind.advisorUpdated,
            at: decision.updatedAt,
          ),
      ],
    ];
    events.sort((a, b) {
      final order = a.at.compareTo(b.at);
      return order == 0 ? a.kind.index.compareTo(b.kind.index) : order;
    });
    return List.unmodifiable(events);
  }
}
