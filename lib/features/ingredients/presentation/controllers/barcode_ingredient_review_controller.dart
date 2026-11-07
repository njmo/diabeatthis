import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/drafts/ingredient_draft.dart';
import '../../data/drafts/ingredient_draft_validation.dart';
import '../../data/models/ingredient_photo_scan_input.dart';
import '../../domain/use_cases/scan_ingredient_from_photos_use_case.dart';

part 'barcode_ingredient_review_controller.g.dart';

@riverpod
class BarcodeIngredientReviewController
    extends _$BarcodeIngredientReviewController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  IngredientDraft? confirmManual(IngredientDraft draft) {
    try {
      if (draft.name.trim().isEmpty ||
          draft.isReference ||
          draft.normalizedBarcode == null) {
        throw ArgumentError('Expected a named ordinary barcode product');
      }
      draft.validateMacroRanges();
      draft.validateBarcode();
      if (!draft.nutritionConfidence.isFinite ||
          draft.nutritionConfidence < 0 ||
          draft.nutritionConfidence > 1) {
        throw ArgumentError('Invalid nutrition confidence');
      }
      state = const AsyncData(null);
      return draft;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return null;
    }
  }

  Future<IngredientDraft?> readLabel(
    IngredientPhotoScanInput input,
    IngredientDraft current,
  ) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final barcode = current.normalizedBarcode;
      if (barcode == null) throw StateError('Missing scanned barcode');
      final result = await ref.read(scanIngredientFromPhotosUseCaseProvider)(
        input,
      );
      if (!ref.mounted) return null;
      if (result.needsRetake ||
          (result.barcode != null && result.barcode != barcode)) {
        throw StateError('The label could not confirm this product');
      }
      final nutrition = result.nutritionPer100g;
      final draft = current.copyWith(
        name: (result.name?.trim().isNotEmpty ?? false)
            ? result.name!.trim()
            : current.name,
        brand: result.brand ?? current.brand,
        barcode: barcode,
        carbsPer100g: nutrition?.carbs ?? current.carbsPer100g,
        fiberPer100g: nutrition?.fiber ?? current.fiberPer100g,
        fatPer100g: nutrition?.fat ?? current.fatPer100g,
        proteinPer100g: nutrition?.protein ?? current.proteinPer100g,
      );
      draft.validateMacroRanges();
      draft.validateBarcode();
      state = const AsyncData(null);
      return draft;
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      return null;
    }
  }
}
