import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart';
import '../../data/models/ingredient_scan_result.dart';
import '../../data/providers/ingredient_photo_scan_capture_provider.dart';
import '../../domain/mappers/ingredient_scan_result_mapper.dart';
import '../../domain/use_cases/scan_ingredient_from_photos_use_case.dart';

part 'ingredient_photo_scan_controller.g.dart';

@riverpod
class IngredientPhotoScanController extends _$IngredientPhotoScanController {
  @override
  FutureOr<IngredientScanResult?> build() {
    return null;
  }

  Future<Ingredient?> scanIngredient() async {
    final input = ref.read(ingredientPhotoScanCaptureControllerProvider);
    if (!input.hasRequiredPhotos) {
      state = const AsyncData(null);
      return null;
    }

    state = const AsyncLoading();

    try {
      final useCase = ref.read(scanIngredientFromPhotosUseCaseProvider);
      final result = await useCase.call(input);
      state = AsyncData(result);
      if (result.needsRetake || result.needsReview) {
        return null;
      }
      return result.toIngredientDraft();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Ingredient? draftFromCurrentResult() {
    final result = state.when(
      data: (value) => value,
      error: (_, _) => null,
      loading: () => null,
    );
    if (result == null || result.needsRetake) {
      return null;
    }
    return result.toIngredientDraft();
  }
}
