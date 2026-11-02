import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../ingredients/data/providers/ingredient_photo_scan_capture_provider.dart';
import '../../../ingredients/data/providers/ingredient_portion_suggestions_provider.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../ingredients/data/providers/ingredient_search_query_provider.dart';
import '../../../ingredients/presentation/controllers/ingredient_barcode_lookup_controller.dart';
import '../../../ingredients/presentation/controllers/ingredient_barcode_scan_feedback_controller.dart';
import '../../../ingredients/presentation/controllers/ingredient_photo_scan_controller.dart';
import '../../../ingredients/presentation/controllers/ingredient_photo_search_controller.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import 'add_meal_ingredient_actions.dart';
import 'add_meal_ingredient_body.dart';

Future<MealIngredientsDraft?> showAddMealIngredientSheet({
  required BuildContext context,
  required WidgetRef ref,
  MealIngredientsDraft? initialDraft,
}) {
  ref.invalidate(addMealIngredientStageProvider);
  ref.invalidate(mealIngredientsDraftProvider);
  ref.invalidate(mealIngredientAmountDraftProvider);
  ref.invalidate(mealIngredientConfidenceDraftProvider);
  ref.invalidate(ingredientDraftProvider);
  ref.invalidate(ingredientSearchQueryProvider);
  ref.invalidate(ingredientPhotoScanCaptureControllerProvider);
  ref.invalidate(ingredientPhotoScanControllerProvider);
  ref.invalidate(ingredientPhotoSearchControllerProvider);
  ref.invalidate(ingredientBarcodeLookupControllerProvider);
  ref.invalidate(ingredientBarcodeScanFeedbackProvider);
  ref.invalidate(ingredientPortionSuggestionsProvider);
  ref.invalidate(portionDraftProvider);

  if (initialDraft != null) {
    // Keep the existing draft subscription while the editor moves between stages.
    ref.watch(mealIngredientsDraftProvider.notifier);
    ref
        .watch(addMealIngredientStageProvider.notifier)
        .editIngredientInline(initialDraft);
  }

  return showModalBottomSheet<MealIngredientsDraft>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (_) => const AddMealIngredient(),
  );
}

class AddMealIngredient extends ConsumerWidget {
  const AddMealIngredient({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep drafts and captures alive while moving through the same sheet.
    ref.watch(portionFilterProvider);
    ref.watch(ingredientDraftProvider);
    ref.watch(ingredientPhotoScanCaptureControllerProvider);
    ref.watch(ingredientPhotoScanControllerProvider);
    ref.watch(ingredientPhotoSearchControllerProvider);
    final stage = ref.watch(addMealIngredientStageProvider);
    final controller = ref.read(addMealIngredientStageProvider.notifier);
    if (stage == AddMealIngredientStage.dismiss) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
    }
    return PopScope(
      canPop:
          stage == AddMealIngredientStage.ingredientSearch ||
          stage == AddMealIngredientStage.dismiss,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.back();
      },
      child: KeyboardAwareBottomSheet(
        header: BottomSheetStepHeader(
          title: ingredientStageTitle(context.lang, stage),
          onBack: stage == AddMealIngredientStage.ingredientSearch
              ? () => Navigator.of(context).pop()
              : controller.back,
        ),
        body: KeyedSubtree(
          key: ValueKey(stage),
          child: const AddMealIngredientBody(),
        ),
        actions: const AddMealIngredientActions(),
      ),
    );
  }
}

String ingredientStageTitle(
  AppLocalizations lang,
  AddMealIngredientStage stage,
) {
  return switch (stage) {
    AddMealIngredientStage.dismiss => '',
    AddMealIngredientStage.ingredientSearch => lang.addIngredientSearchTitle,
    AddMealIngredientStage.ingredientCreationMethod => lang.ingredientCreateNew,
    AddMealIngredientStage.ingredientPhotoScan =>
      lang.addIngredientFromPhotosTitle,
    AddMealIngredientStage.ingredientForm => lang.ingredientCreateNew,
    AddMealIngredientStage.referenceIngredientForm =>
      lang.ingredientReferenceDishTitle,
    AddMealIngredientStage.portionAddNewSearch =>
      lang.addIngredientPickPortionTitle,
    AddMealIngredientStage.definedPortionsSearch =>
      lang.addIngredientSearchExistingPortionTitle,
    AddMealIngredientStage.portionAddNewForm =>
      lang.addIngredientNewPortionTitle,
    AddMealIngredientStage.portionSpecifyAmount =>
      lang.addIngredientPortionWeightTitle,
    AddMealIngredientStage.amountForm => lang.ingredientPortionAndAmountTitle,
    AddMealIngredientStage.summary => lang.addIngredientSummaryTitle,
  };
}
