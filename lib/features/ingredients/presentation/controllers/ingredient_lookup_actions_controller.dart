import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/ingredient_provider.dart';
import '../models/ingredient_barcode_scan_outcome.dart';
import '../services/ingredient_barcode_scanner.dart';
import '../widgets/ingredient_barcode_scan_outcome_dialog.dart';
import 'ingredient_barcode_scan_feedback_controller.dart';

class IngredientLookupActionsController {
  const IngredientLookupActionsController(this.ref);
  final WidgetRef ref;

  Future<void> searchByCode(BuildContext context) async {
    final barcode = await ref
        .read(ingredientBarcodeScannerProvider)
        .scan(context);
    if (barcode == null || !context.mounted) return;
    final controller = ref.read(addMealIngredientStageProvider.notifier);
    final outcome = await controller.scanIngredientBarcode(barcode);
    if (!context.mounted) return;
    if (outcome.type == IngredientBarcodeScanOutcomeType.existingIngredient) {
      controller.continueWithExistingBarcodeIngredient(
        outcome.existingIngredient!,
      );
      await controller.integrateAssignedPortions();
      return;
    }
    final shouldContinue = await showIngredientBarcodeScanOutcomeDialog(
      context: context,
      outcome: outcome,
      errorMessage: outcome.error == null
          ? null
          : ingredientBarcodeScanErrorMessage(outcome.error!),
    );
    if (!context.mounted) return;
    if (outcome.type == IngredientBarcodeScanOutcomeType.failed) {
      ref.read(ingredientDraftProvider.notifier).setBarcode(barcode);
      ref
          .read(ingredientBarcodeScanFeedbackProvider.notifier)
          .show(
            ingredientBarcodeScanNoUsableDataMessageForError(outcome.error),
          );
      return;
    }
    if (shouldContinue == true) {
      ref.invalidate(ingredientBarcodeScanFeedbackProvider);
      controller.continueWithBarcodeIngredientDraft(outcome.draft!);
    }
  }
}
