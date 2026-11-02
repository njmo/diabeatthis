import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../ingredients/data/providers/ingredient_photo_scan_capture_provider.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../ingredients/presentation/controllers/ingredient_photo_scan_controller.dart';
import '../../../ingredients/presentation/widgets/ingredient_search.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../controllers/ingredient_flow_actions_controller.dart';

class AddMealIngredientActions extends ConsumerWidget {
  const AddMealIngredientActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(addMealIngredientStageProvider);
    final controller = ref.read(addMealIngredientStageProvider.notifier);
    final lang = context.lang;
    if (stage == AddMealIngredientStage.dismiss ||
        stage == AddMealIngredientStage.ingredientCreationMethod) {
      return const SizedBox.shrink();
    }
    final isSearch = stage == AddMealIngredientStage.ingredientSearch;
    final isPortionSearch =
        stage == AddMealIngredientStage.definedPortionsSearch;
    final isPhotoScan = stage == AddMealIngredientStage.ingredientPhotoScan;
    final scanState = ref.watch(ingredientPhotoScanControllerProvider);
    final photos = ref.watch(ingredientPhotoScanCaptureControllerProvider);
    final selected = ref.watch(ingredientDraftProvider);
    final canContinue =
        (!isSearch || selected.hasSearchSelection) &&
        (!isPhotoScan || (!scanState.isLoading && photos.hasRequiredPhotos));
    final label = switch (stage) {
      AddMealIngredientStage.ingredientSearch =>
        selected.hasSearchSelection
            ? lang.ingredientSelectNamed(selected.name)
            : lang.ingredientSelect,
      AddMealIngredientStage.ingredientPhotoScan =>
        scanState.isLoading
            ? lang.addIngredientReadingData
            : lang.addIngredientReadData,
      AddMealIngredientStage.amountForm => lang.ingredientReviewAmount,
      AddMealIngredientStage.summary => lang.addIngredientTitle,
      _ => lang.addIngredientNext,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSearch) ...[
          OutlinedButton.icon(
            onPressed: controller.startIngredientCreation,
            icon: const Icon(Icons.add),
            label: Text(lang.ingredientCreateNew),
          ),
          const SizedBox(height: 8),
        ],
        if (isPortionSearch) ...[
          const Divider(),
          Text(
            lang.ingredientWithoutPortion,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          TextButton.icon(
            onPressed: controller.setOverride,
            icon: const Icon(Icons.scale_outlined),
            label: Text(lang.addIngredientAddInGrams),
          ),
          const SizedBox(height: 4),
        ],
        FilledButton(
          onPressed: canContinue
              ? () => IngredientFlowActionsController(ref).continueFlow(context)
              : null,
          child: Text(label, maxLines: 2, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
