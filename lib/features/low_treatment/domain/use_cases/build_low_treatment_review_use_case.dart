import '../../../../core/domain/model/treat.dart';
import '../models/low_treatment_review_decision.dart';
import '../models/low_treatment_review_entry.dart';
import '../models/recorded_low_treatment.dart';

class BuildLowTreatmentReviewUseCase {
  const BuildLowTreatmentReviewUseCase();

  List<LowTreatmentReviewEntry> call({
    required List<Treat> events,
    required List<RecordedLowTreatment> recorded,
    required List<LowTreatmentReviewDecision> decisions,
  }) {
    final groups = <int, List<Treat>>{};
    for (final event in events.where(
      (event) => event.isValid && event.carbs > 0,
    )) {
      groups
          .putIfAbsent(event.createdAt.millisecondsSinceEpoch, () => [])
          .add(event);
    }
    final linkedMeals = <int>{};
    final entries = <LowTreatmentReviewEntry>[];
    for (final group in groups.values) {
      final event =
          group.where((entry) => entry.externalId != null).firstOrNull ??
          group.first;
      final ambiguous = group.any(
        (other) =>
            other.carbs != event.carbs ||
            (other.externalId != null &&
                event.externalId != null &&
                other.externalId != event.externalId),
      );
      final decision = decisions
          .where((d) => d.occurredAt == event.createdAt)
          .firstOrNull;
      final conflict =
          decision?.externalId != null &&
          event.externalId != null &&
          decision!.externalId != event.externalId;
      final low = recorded
          .where((low) => low.mealId == decision?.mealId)
          .firstOrNull;
      if (low != null && !ambiguous && !conflict) linkedMeals.add(low.mealId);
      entries.add(
        LowTreatmentReviewEntry(
          event: event,
          recorded: ambiguous || conflict ? null : low,
          dismissed: !ambiguous && !conflict && (decision?.dismissed ?? false),
          ambiguous: ambiguous || conflict,
          staleDecision: conflict,
        ),
      );
    }
    entries.addAll(
      recorded
          .where((low) => !linkedMeals.contains(low.mealId))
          .map((low) => LowTreatmentReviewEntry(recorded: low)),
    );
    entries.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return List.unmodifiable(entries);
  }
}
