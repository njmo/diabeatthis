import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/drafts/ingredient_draft.dart';
import '../../data/drafts/ingredient_draft_validation.dart';
import '../../data/mappers/ingredient_draft_mapper.dart';
import '../controllers/ingredient_barcode_lookup_controller.dart';
import '../models/ingredient_barcode_scan_outcome.dart';
import '../widgets/barcode_ingredient_review_sheet.dart';
import 'ingredient_barcode_scanner.dart';

/// Resolves the existing scanner/OFF flow without persisting a product early.
Future<IngredientDraft?> selectBarcodeIngredient(
  BuildContext context,
  WidgetRef ref,
) async {
  final code = await ref.read(ingredientBarcodeScannerProvider).scan(context);
  if (code == null || !context.mounted || !ref.context.mounted) return null;
  final subscription = ref.listenManual(
    ingredientBarcodeLookupControllerProvider,
    (_, _) {},
  );
  final IngredientBarcodeScanOutcome outcome;
  try {
    outcome = await ref
        .read(ingredientBarcodeLookupControllerProvider.notifier)
        .scanForSelection(code);
  } finally {
    subscription.close();
  }
  if (!context.mounted || !ref.context.mounted) return null;
  if (outcome.existingIngredient case final existing?) {
    return existing.toDraft();
  }
  final complete =
      outcome.type == IngredientBarcodeScanOutcomeType.newDraft &&
      (outcome.draft?.hasValidMacroRanges ?? false);
  final draft =
      (outcome.draft ??
              IngredientDraft.draft(
                name: '',
                carbsPer100g: 0,
                fiberPer100g: 0,
                proteinPer100g: 0,
                fatPer100g: 0,
                nutritionConfidence: .25,
                isReference: false,
              ))
          .copyWith(barcode: code, nutritionConfidence: complete ? .8 : .25);
  return showBarcodeIngredientReviewSheet(
    context,
    draft: draft,
    needsReview: !complete,
  );
}
