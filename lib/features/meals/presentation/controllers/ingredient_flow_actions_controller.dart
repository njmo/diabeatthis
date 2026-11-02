import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../ingredients/data/models/ingredient_scan_result.dart';
import '../../../ingredients/presentation/controllers/ingredient_photo_scan_controller.dart';
import '../../../ingredients/presentation/widgets/ingredient_scan_review_dialog.dart';
import '../../data/providers/add_ingredients_provider.dart';

class IngredientFlowActionsController {
  const IngredientFlowActionsController(this.ref);
  final WidgetRef ref;

  Future<void> continueFlow(BuildContext context) async {
    final stage = ref.read(addMealIngredientStageProvider);
    final controller = ref.read(addMealIngredientStageProvider.notifier);
    FocusScope.of(context).unfocus();
    if (stage == AddMealIngredientStage.summary) {
      Navigator.of(context).pop(controller.completeAmountForm());
      return;
    }
    if (stage == AddMealIngredientStage.ingredientPhotoScan) {
      await controller.nextStage();
      if (!context.mounted) return;
      final result = ref
          .read(ingredientPhotoScanControllerProvider)
          .asData
          ?.value;
      if (ref.read(addMealIngredientStageProvider) ==
              AddMealIngredientStage.ingredientPhotoScan &&
          result?.status == IngredientScanStatus.needsReview) {
        final accepted = await showIngredientScanReviewDialog(
          context: context,
          result: result!,
        );
        if (accepted == true && context.mounted) {
          controller.continueWithIngredientScanReview();
        }
      }
      return;
    }
    final formKey = switch (stage) {
      AddMealIngredientStage.ingredientSearch => ref.read(
        ingredientSearchFormKeyProvider,
      ),
      AddMealIngredientStage.ingredientForm ||
      AddMealIngredientStage.referenceIngredientForm => ref.read(
        ingredientFormKeyProvider,
      ),
      _ => ref.read(mealIngredientFormKeyProvider),
    };
    if (validateForm(formKey)) {
      if (stage == AddMealIngredientStage.portionAddNewForm) {
        await controller.confirmNewPortion();
      } else {
        await controller.nextStage();
        if (stage == AddMealIngredientStage.ingredientSearch) {
          await controller.integrateAssignedPortions();
        }
      }
    }
  }
}
