import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/ingredient_photo_scan_input.dart';
import '../../data/models/ingredient_photo_search_result.dart';
import '../../data/providers/ingredient_photo_scan_capture_provider.dart';
import '../../domain/use_cases/search_ingredient_from_photo_use_case.dart';

part 'ingredient_photo_search_controller.g.dart';

class IngredientPhotoSearchState {
  final IngredientPhotoSearchResult? result;
  final IngredientPhotoCaptureResult? captureError;

  const IngredientPhotoSearchState({
    required this.result,
    required this.captureError,
  });

  const IngredientPhotoSearchState.empty() : result = null, captureError = null;
}

@riverpod
class IngredientPhotoSearchController
    extends _$IngredientPhotoSearchController {
  @override
  FutureOr<IngredientPhotoSearchState> build() {
    return const IngredientPhotoSearchState.empty();
  }

  Future<void> captureAndSearch() async {
    state = const AsyncLoading();
    ref.invalidate(ingredientPhotoScanCaptureControllerProvider);

    final captureResult = await ref
        .read(ingredientPhotoScanCaptureControllerProvider.notifier)
        .capture(IngredientPhotoScanPhoto.front);
    if (captureResult.state != IngredientPhotoCaptureState.captured) {
      state = AsyncData(
        IngredientPhotoSearchState(
          result: null,
          captureError:
              captureResult.state == IngredientPhotoCaptureState.cancelled
              ? null
              : captureResult,
        ),
      );
      return;
    }

    try {
      final input = ref.read(ingredientPhotoScanCaptureControllerProvider);
      final result = await ref
          .read(searchIngredientFromPhotoUseCaseProvider)
          .call(input);
      state = AsyncData(
        IngredientPhotoSearchState(result: result, captureError: null),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void reset() {
    state = const AsyncData(IngredientPhotoSearchState.empty());
  }
}
