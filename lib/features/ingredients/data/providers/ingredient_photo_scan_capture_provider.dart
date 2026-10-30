import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/media/camera_permission_service.dart';
import '../../../../core/media/camera_photo_capture_result.dart';
import '../../../../core/media/providers/camera_permission_service_provider.dart';
import '../models/ingredient_photo_scan_input.dart';

part 'ingredient_photo_scan_capture_provider.g.dart';

enum IngredientPhotoCaptureState {
  captured,
  cancelled,
  cameraUnavailable,
  permissionDenied,
  permissionPermanentlyDenied,
  permissionRestricted,
}

class IngredientPhotoCaptureResult {
  final IngredientPhotoCaptureState state;

  const IngredientPhotoCaptureResult(this.state);

  bool get canOpenSettings =>
      state == IngredientPhotoCaptureState.permissionPermanentlyDenied ||
      state == IngredientPhotoCaptureState.permissionRestricted;
}

@riverpod
class IngredientPhotoScanCaptureController
    extends _$IngredientPhotoScanCaptureController {
  @override
  IngredientPhotoScanInput build() {
    return const IngredientPhotoScanInput();
  }

  Future<IngredientPhotoCaptureResult> capture(
    IngredientPhotoScanPhoto photo, {
    required Future<CameraPhotoCaptureResult> Function() capturePhoto,
  }) async {
    final permission = await ref
        .read(cameraPermissionServiceProvider)
        .requestCamera();
    if (!permission.canUseCamera) {
      return IngredientPhotoCaptureResult(
        _mapPermissionState(permission.state),
      );
    }

    if (!ref.mounted) {
      return const IngredientPhotoCaptureResult(
        IngredientPhotoCaptureState.cancelled,
      );
    }
    final capturedPhoto = await capturePhoto();
    if (capturedPhoto.state == CameraPhotoCaptureState.cancelled) {
      return const IngredientPhotoCaptureResult(
        IngredientPhotoCaptureState.cancelled,
      );
    }
    if (!capturedPhoto.hasPhoto) {
      return const IngredientPhotoCaptureResult(
        IngredientPhotoCaptureState.cameraUnavailable,
      );
    }

    if (!ref.mounted) {
      return const IngredientPhotoCaptureResult(
        IngredientPhotoCaptureState.cancelled,
      );
    }

    state = state.withPhoto(photo, capturedPhoto.path!);
    return const IngredientPhotoCaptureResult(
      IngredientPhotoCaptureState.captured,
    );
  }

  void reset() {
    state = const IngredientPhotoScanInput();
  }
}

IngredientPhotoCaptureState _mapPermissionState(CameraPermissionState state) {
  return switch (state) {
    CameraPermissionState.granted => IngredientPhotoCaptureState.captured,
    CameraPermissionState.denied =>
      IngredientPhotoCaptureState.permissionDenied,
    CameraPermissionState.permanentlyDenied =>
      IngredientPhotoCaptureState.permissionPermanentlyDenied,
    CameraPermissionState.restricted =>
      IngredientPhotoCaptureState.permissionRestricted,
  };
}
