import '../../../meal_analysis/domain/models/meal_ai_facts.dart';
import '../../../meal_analysis/domain/models/meal_record_evidence.dart';
import '../../common/models/meal_wizard_assignment.dart';
import '../models/meal_details_data.dart';
import 'similar_meal_query_mapper.dart';

class MealAiFactsMapper {
  const MealAiFactsMapper();
  MealAiFacts map(
    MealDetailsData details, {
    DateTime? cutoff,
    List<MealWizardAssignment>? wizardAssignments,
  }) {
    if (!details.meal.isEaten || details.meal.isLowTreatment) {
      throw StateError('An eaten meal is required');
    }
    final snapshot = details.preferredSummarySnapshot;
    if (cutoff != null &&
        (snapshot != null &&
                (snapshot.createdAt.isAfter(cutoff) ||
                    snapshot.updatedAt.isAfter(cutoff)) ||
            details.ingredients.any(
              (i) => i.createdAt.isAfter(cutoff) || i.updatedAt.isAfter(cutoff),
            ))) {
      throw StateError('Comparison nutrition was edited after the target meal');
    }
    final query = const SimilarMealQueryMapper().map(details);
    return MealAiFacts(
      evidence: MealRecordEvidence(
        eatingTimeSource: details.recordedEatingStartedAt != null
            ? MealEatingTimeSource.recordedStage
            : details.meal.summarizedAt != null
            ? MealEatingTimeSource.summaryTimestamp
            : MealEatingTimeSource.plannedFallback,
        nutritionConfidence: snapshot == null
            ? null
            : MealNutritionConfidence(
                carbsQuantity: snapshot.carbWeightedQuantityConfidence,
                carbsNutrition: snapshot.carbWeightedNutritionConfidence,
                carbsEffective: snapshot.carbWeightedEffectiveConfidence,
                fatProteinQuantity: snapshot.wbtWeightedQuantityConfidence,
                fatProteinNutrition: snapshot.wbtWeightedNutritionConfidence,
                fatProteinEffective: snapshot.wbtWeightedEffectiveConfidence,
              ),
        wizardAssignments: wizardAssignments,
      ),
      mealId: details.meal.id,
      name: details.meal.name,
      eatenAt: details.analysisTime,
      endedAt: details.recordedEatingEndedAt,
      wait: details.recordedWait,
      window: details.observationWindow,
      macroSource: details.hasConsumedData ? 'consumed' : 'planned',
      macros: query?.target,
      composition: query?.composition,
      ingredients: [
        for (final ingredient in details.ingredients)
          if (details.hasConsumedData
              ? ingredient.consumedTotalGrams > 0
              : !ingredient.isExtra && ingredient.plannedTotalGrams > 0)
            (
              name: ingredient.ingredientName,
              grams: details.hasConsumedData
                  ? ingredient.consumedTotalGrams
                  : ingredient.plannedTotalGrams,
            ),
      ],
      stages: [
        for (final stage in details.statusHistory)
          if (cutoff == null || !stage.createdAt.isAfter(cutoff))
            (status: stage.status, at: stage.createdAt),
      ],
    );
  }
}
