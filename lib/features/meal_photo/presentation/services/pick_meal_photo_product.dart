import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/ingredient_catalog/ingredient_search_item.dart';
import '../../../../common/ingredient_catalog/widgets/ingredient_catalog_picker.dart';
import '../../../../common/l10n/language.dart';
import '../../../ingredients/presentation/services/select_barcode_ingredient.dart';
import '../../data/meal_photo_barcode_candidate_factory.dart';
import '../../domain/models/meal_photo_candidate.dart';
import '../providers/meal_photo_providers.dart';

Future<MealPhotoCandidate?> pickMealPhotoProduct(
  BuildContext context,
  WidgetRef ref, {
  MealPhotoCandidate? currentProduct,
  String initialQuery = '',
}) async {
  final candidates = ref.read(mealPhotoCandidatesProvider);
  final language = Localizations.localeOf(context).languageCode;
  MealPhotoCandidate? scannedProduct;
  final selected = await showIngredientCatalogPicker(
    context,
    includeReferenceIngredients: false,
    searchOnly: true,
    initialQuery: initialQuery,
    selectedItem: currentProduct == null
        ? null
        : IngredientSearchItem(
            identity: currentProduct.identity,
            name: currentProduct.name,
            localIngredientId: currentProduct.localIngredientId,
            iconAssetPath: currentProduct.iconAssetPath,
            sourceRevision: currentProduct.catalogRevision,
          ),
    onScanBarcode: (pickerContext) async {
      if (!context.mounted) return;
      try {
        final draft = await selectBarcodeIngredient(pickerContext, ref);
        if (draft == null || !pickerContext.mounted || !context.mounted) return;
        scannedProduct = const MealPhotoBarcodeCandidateFactory()(draft);
        Navigator.pop(pickerContext);
      } catch (_) {
        if (pickerContext.mounted) {
          ScaffoldMessenger.of(pickerContext).showSnackBar(
            SnackBar(
              content: Text(pickerContext.lang.barcodeReviewSelectionFailed),
            ),
          );
        }
      }
    },
  );
  if (!context.mounted) return null;
  if (scannedProduct != null) return scannedProduct;
  if (selected == null) return null;
  if (selected.identity == currentProduct?.identity) return currentProduct;
  return candidates.resolve(selected, languageCode: language);
}
