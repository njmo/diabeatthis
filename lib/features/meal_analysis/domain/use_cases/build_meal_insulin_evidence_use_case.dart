import '../../../../common/history/bolus_wizard_grouping.dart';
import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/domain/model/manual_bolus.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../../meals/common/models/meal_wizard_assignment.dart';
import '../models/meal_linked_insulin_evidence.dart';

/// Confirmed meal/calculator identities are separate from heuristic delivery candidates.
class BuildMealInsulinEvidenceUseCase {
  const BuildMealInsulinEvidenceUseCase();
  List<MealLinkedInsulinEvidence>? call({
    required int mealId,
    required List<MealWizardAssignment>? assignments,
    required List<Treatment>? treatments,
    required DateTime cutoff,
  }) {
    if (assignments == null) return null;
    final valid = treatments
        ?.where(
          (t) =>
              t.isValid && t.createdAt != null && !t.createdAt!.isAfter(cutoff),
        )
        .toList();
    final calculators =
        valid
            ?.whereType<BolusWizard>()
            .where(
              (w) =>
                  !(w.calculatorResult?.timestamp ??
                          w.calculatorResult?.dateCreated ??
                          w.createdAt)
                      .isAfter(cutoff),
            )
            .toList() ??
        [];
    final boluses = valid?.whereType<ManualBolus>().toList() ?? [];
    bool candidate(BolusWizard wizard, ManualBolus bolus) =>
        wizard.insulin.isFinite &&
        wizard.insulin > 0 &&
        bolus.insulin.isFinite &&
        bolus.insulin > 0 &&
        (wizard.insulin - bolus.insulin).abs() <= 0.001 &&
        !bolus.createdAt.isBefore(wizard.createdAt) &&
        bolus.createdAt.difference(wizard.createdAt) <=
            BolusWizardGrouping.carbSubmissionWindow;
    final result = <MealLinkedInsulinEvidence>[];
    for (final link in assignments.where(
      (a) => a.mealId == mealId && !a.dismissed,
    )) {
      final matches = calculators.where(link.matches).toList();
      final wizard = matches.length == 1 ? matches.single : null;
      final candidates = wizard == null
          ? <ManualBolus>[]
          : boluses.where((b) => candidate(wizard, b)).toList();
      final unique =
          wizard != null &&
          candidates.length == 1 &&
          calculators.where((w) => candidate(w, candidates.single)).length == 1;
      final association = valid == null
          ? MealBolusAssociation.historyUnavailable
          : matches.isEmpty
          ? MealBolusAssociation.calculatorMissing
          : matches.length > 1
          ? MealBolusAssociation.calculatorAmbiguous
          : candidates.isEmpty
          ? MealBolusAssociation.noRecordedBolusCandidate
          : !unique
          ? MealBolusAssociation.bolusCandidateAmbiguous
          : MealBolusAssociation.temporalAmountCandidate;
      result.add(
        MealLinkedInsulinEvidence(
          role: link.type,
          assignedAt: link.recordedAt,
          calculator: wizard,
          bolusCandidate: unique ? candidates.single : null,
          association: association,
          candidateCount: valid == null || wizard == null
              ? null
              : candidates.length,
        ),
      );
    }
    return List.unmodifiable(result);
  }
}
