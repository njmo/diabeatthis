import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/media/camera_permission_service.dart';
import '../../../../common/media/providers/camera_permission_service_provider.dart';
import '../models/ingredient_photo_scan_input.dart';

part 'ingredient_photo_scan_capture_provider.g.dart';

@riverpod
class IngredientPhotoScanCaptureController
    extends _$IngredientPhotoScanCaptureController {
  @override
  IngredientPhotoScanInput build() {
    return const IngredientPhotoScanInput();
  }

  Future<CameraPermissionResult> capture(IngredientPhotoScanPhoto photo) async {
    final permission = await ref
        .read(cameraPermissionServiceProvider)
        .requestCamera();
    if (!permission.canUseCamera) {
      return permission;
    }

    state = state.withPhoto(photo, debugIngredientPhotoScanPath(photo));
    return permission;
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
