import '../../../../common/analysis/dml_timestamp.dart';
import '../models/before_meal_context.dart';
import '../models/meal_outcome_context.dart';
import '../models/meal_record_evidence.dart';
import '../use_cases/build_meal_insulin_evidence_use_case.dart';

double? _confidence(double? value) =>
    value != null && value.isFinite && value >= 0 && value <= 1 ? value : null;

Map<String, Object?> mealRecordEvidenceDml({
  required int mealId,
  required MealRecordEvidence evidence,
  required DateTime mealTime,
  required Duration? workflowWait,
  required BeforeMealContext before,
  required MealOutcomeContext? outcome,
}) {
  final nutrition = evidence.nutritionConfidence;
  final treatments = outcome?.treatments ?? before.treatments;
  final end = outcome?.observedUntil ?? before.asOf;
  final links = const BuildMealInsulinEvidenceUseCase()(
    mealId: mealId,
    assignments: evidence.wizardAssignments,
    treatments: treatments,
    cutoff: end,
  );
  final after =
      outcome?.glucose
          .where(
            (g) =>
                !g.date.isBefore(mealTime) &&
                g.date.difference(mealTime) <= const Duration(minutes: 5),
          )
          .toList()
        ?..sort((a, b) => a.date.compareTo(b.date));
  final firstAfter = after?.firstOrNull;
  final recordedStart =
      evidence.eatingTimeSource == MealEatingTimeSource.recordedStage;
  return {
    'meal_reference_at': dmlTimestamp(mealTime),
    'eating_time_source': evidence.eatingTimeSource.name,
    'workflow_wait_min': workflowWait == null
        ? null
        : workflowWait.inSeconds / 60,
    'latest_cgm_before_meal': before.latestCgm == null
        ? null
        : {
            'at': dmlTimestamp(before.latestCgm!.date),
            'mg_dl': before.latestCgm!.sgv,
            'direction': before.latestCgm!.direction.isEmpty
                ? null
                : before.latestCgm!.direction,
            'age_min':
                mealTime.difference(before.latestCgm!.date).inSeconds / 60,
          },
    'first_cgm_after_meal': firstAfter == null
        ? null
        : {
            'at': dmlTimestamp(firstAfter.date),
            'mg_dl': firstAfter.sgv,
            'delay_min': firstAfter.date.difference(mealTime).inSeconds / 60,
          },
    'nutrition_confidence': mealNutritionConfidenceDml(nutrition),
    'linked_calculators': links == null
        ? null
        : [
            for (final entry in links)
              {
                'role': entry.role.name,
                'relation_recorded_at': entry.assignedAt == null
                    ? null
                    : dmlTimestamp(entry.assignedAt!),
                'calculator_at': entry.calculator == null
                    ? null
                    : dmlTimestamp(entry.calculator!.createdAt),
                'calculated_units':
                    entry
                            .calculator
                            ?.calculatorResult
                            ?.totalInsulin
                            ?.isFinite ==
                        true
                    ? entry.calculator!.calculatorResult!.totalInsulin
                    : null,
                'delivery_association': entry.association.name,
                'delivery_candidate_count': entry.candidateCount,
                'candidate_recorded_bolus': entry.bolusCandidate == null
                    ? null
                    : {
                        'at': dmlTimestamp(entry.bolusCandidate!.createdAt),
                        'units': entry.bolusCandidate!.insulin,
                      },
                'candidate_bolus_to_recorded_eating_min':
                    !recordedStart || entry.bolusCandidate == null
                    ? null
                    : mealTime
                              .difference(entry.bolusCandidate!.createdAt)
                              .inSeconds /
                          60,
              },
          ],
    'limitations': [
      'Meal start and workflow wait are user/app records, not measured ingestion or confirmed delivery.',
      'Positive candidate_bolus_to_recorded_eating_min means candidate bolus before eating; negative means after.',
      'A confirmed meal/calculator link does not prove a calculator-adjacent bolus belongs to that meal.',
      'Delivery candidates require a unique same-amount record within 10 seconds after the calculator; this remains a heuristic, not verified attribution.',
      'No candidate or missing workflow wait does not mean no bolus or zero waiting.',
      'Relations describe current confirmed assignments and may have been reviewed after the meal.',
    ],
  };
}

Map<String, Object?>? mealNutritionConfidenceDml(
  MealNutritionConfidence? nutrition,
) => nutrition == null
    ? null
    : {
        'scale': 'saved_estimate_0_to_1_not_measured_accuracy',
        'carbs_quantity': _confidence(nutrition.carbsQuantity),
        'carbs_nutrition': _confidence(nutrition.carbsNutrition),
        'carbs_effective': _confidence(nutrition.carbsEffective),
        'fat_protein_quantity': _confidence(nutrition.fatProteinQuantity),
        'fat_protein_nutrition': _confidence(nutrition.fatProteinNutrition),
        'fat_protein_effective': _confidence(nutrition.fatProteinEffective),
      };
