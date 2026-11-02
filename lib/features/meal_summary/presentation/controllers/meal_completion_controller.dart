import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/meal/meal_completion_decision.dart';
import '../../../../common/widgets/meal_completion/meal_shortfall_review_dialog.dart';
import '../../domain/use_cases/complete_meal_use_case.dart';
import '../../domain/utils/meal_completion_amounts.dart';
import '../models/meal_summary_draft.dart';
import '../providers/meal_completion_context_provider.dart';
import '../utils/meal_completion_aaps_carbs.dart';
import '../utils/meal_completion_shortfall.dart';
import '../utils/meal_summary_carbs_delta.dart';

final mealCompletionControllerProvider = Provider<MealCompletionController>(
  (ref) => MealCompletionController(ref),
);

/// Coordinates completion while the view owns dialogs and navigation.
class MealCompletionController {
  const MealCompletionController(this.ref);
  final Ref ref;

  Future<MealCompletionContext> refresh(int mealId) =>
      ref.refresh(mealCompletionContextProvider(mealId).future);

  bool needsReview(MealSummaryDraft draft, MealCompletionContext details) =>
      mealCompletionNeedsShortfallReview(
        draft,
        hasRecordedBolus: details.hasRecordedBolus,
        coveredNetCarbs: details.coveredNetCarbs,
      ) ||
      (details.hasRecordedBolus &&
          !details.requiresBolus &&
          calculateMealSummaryCarbsDelta(draft).roundedTotal < 0);

  Future<MealCompletionResult> complete({
    required MealSummaryDraft draft,
    required MealCompletionContext details,
    required MealShortfallAction? action,
    required DateTime endedAt,
    required bool finishingRefill,
  }) async {
    final useCase = ref.read(completeMealUseCaseProvider);
    final reviewedDraft = draft.copyWith(
      reviewedBolusCoverage: details.bolusCoverage,
      correctionChoice: switch (action) {
        MealShortfallAction.saveActual =>
          MealCarbsCorrectionChoice.withoutCorrection,
        MealShortfallAction.saveAndCorrect =>
          MealCarbsCorrectionChoice.correctionRequested,
        _ => null,
      },
    );
    final result = finishingRefill
        ? await useCase.completeRefill(
            draft: reviewedDraft,
            choice: inferMealCompletionChoice(draft),
            endedAt: endedAt,
          )
        : await useCase.call(
            draft: reviewedDraft,
            choice: inferMealCompletionChoice(draft),
            endedAt: endedAt,
          );
    if (result.requiresBolus) return result;
    var instruction = result.aapsCarbs;
    // Preserve the nullable result contract for existing completion providers.
    if (instruction == null &&
        mealCompletionCanOpenAapsSuggestion(
          draft,
          hasRecordedBolus: details.hasRecordedBolus,
        )) {
      instruction = calculateMealCompletionAapsCarbs(draft);
    }
    if (action == MealShortfallAction.saveAndCorrect) {
      instruction = MealSummaryAapsCarbs(
        carbs: calculateMealSummaryCarbsDelta(draft).roundedTotal,
        extendedCarbs: instruction?.extendedCarbs ?? 0,
      );
    } else if (action == MealShortfallAction.saveActual ||
        mealCompletionNeedsShortfallReview(
          draft,
          hasRecordedBolus: details.hasRecordedBolus,
          coveredNetCarbs: details.coveredNetCarbs,
        )) {
      instruction = null;
    }
    return MealCompletionResult(
      meal: result.meal,
      requiresBolus: result.requiresBolus,
      consumedCarbs: result.consumedCarbs,
      consumedExtendedCarbs: result.consumedExtendedCarbs,
      endedAt: result.endedAt,
      aapsCarbs: instruction,
    );
  }
}
