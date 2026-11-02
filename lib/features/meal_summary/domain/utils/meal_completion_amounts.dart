import '../../presentation/models/meal_completion_choice.dart';
import '../../presentation/models/meal_summary_draft.dart';

bool mealCompletionHasNoFood(MealSummaryDraft draft) =>
    draft.itemsById.values.every((item) => item.consumedAmount == 0) &&
    draft.extraItems.every((item) => item.amount == 0);

MealCompletionChoice inferMealCompletionChoice(MealSummaryDraft draft) {
  if (draft.extraItems.isNotEmpty ||
      draft.itemsById.values.any(
        (item) => item.consumedAmount > item.reportedAmount + 0.001,
      )) {
    return MealCompletionChoice.more;
  }
  if (draft.itemsById.values.any(
    (item) => item.consumedAmount < item.reportedAmount - 0.001,
  )) {
    return MealCompletionChoice.less;
  }
  return MealCompletionChoice.all;
}

double? mealCompletionReportedGrams(MealSummaryDraft draft) {
  if (draft.itemsById.isEmpty ||
      draft.itemsById.values.any((item) => item.gramsPerAmount == null)) {
    return null;
  }
  return draft.itemsById.values.fold<double>(
    0,
    (sum, item) => sum + item.reportedAmount * item.gramsPerAmount!,
  );
}

double? mealCompletionConsumedGrams(MealSummaryDraft draft) {
  if (draft.itemsById.isEmpty ||
      draft.itemsById.values.any((item) => item.gramsPerAmount == null)) {
    return null;
  }
  return draft.itemsById.values.fold<double>(
    0,
    (sum, item) => sum + item.consumedAmount * item.gramsPerAmount!,
  );
}

bool mealCompletionAmountsValid(
  MealSummaryDraft draft,
  MealCompletionChoice? choice,
) {
  if (choice == null || draft.itemsById.isEmpty) return false;
  if (draft.itemsById.values.any(
    (item) =>
        !item.consumedAmount.isFinite ||
        item.consumedAmount < 0 ||
        !item.consumedConfidence.isFinite ||
        item.consumedConfidence < 0 ||
        item.consumedConfidence > 1,
  )) {
    return false;
  }
  if (draft.extraItems.any(
    (item) => !item.amount.isFinite || item.amount <= 0,
  )) {
    return false;
  }
  if (!draft.itemsById.values.any((item) => item.consumedAmount > 0) &&
      draft.extraItems.isEmpty) {
    return false;
  }
  final less = draft.itemsById.values.any(
    (item) => item.consumedAmount < item.reportedAmount - 0.001,
  );
  final more =
      draft.itemsById.values.any(
        (item) => item.consumedAmount > item.reportedAmount + 0.001,
      ) ||
      draft.extraItems.isNotEmpty;
  return switch (choice) {
    MealCompletionChoice.all => !less && !more,
    MealCompletionChoice.less => less,
    MealCompletionChoice.more => more,
  };
}
