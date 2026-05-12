import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/ingredient_photo_scan_input.dart';

part 'ingredient_photo_scan_capture_provider.g.dart';

@riverpod
class IngredientPhotoScanCaptureController
    extends _$IngredientPhotoScanCaptureController {
  @override
  IngredientPhotoScanInput build() {
    return const IngredientPhotoScanInput();
  }

  void capture(IngredientPhotoScanPhoto photo) {
    state = state.withPhoto(photo, debugIngredientPhotoScanPath(photo));
  }

  void reset() {
    state = const IngredientPhotoScanInput();
  }
}

String debugIngredientPhotoScanPath(IngredientPhotoScanPhoto photo) {
  final name = switch (photo) {
    IngredientPhotoScanPhoto.front => 'front',
    IngredientPhotoScanPhoto.nutritionLabel => 'nutrition-label',
  };
  return 'debug://ingredient-photo-scan/$name-${DateTime.now().millisecondsSinceEpoch}.jpg';
}
