import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/media/camera_photo_capture_result.dart';
import '../../data/models/ingredient_photo_scan_input.dart';
import '../screens/ingredient_photo_camera_screen.dart';

Future<CameraPhotoCaptureResult> captureIngredientPhoto(
  BuildContext context,
  IngredientPhotoScanPhoto photo,
) async {
  if (!context.mounted) return const CameraPhotoCaptureResult.cancelled();
  final isFront = photo == IngredientPhotoScanPhoto.front;
  final lang = context.lang;
  final path = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => IngredientPhotoCameraScreen(
        title: isFront
            ? lang.framedCameraFrontTitle
            : lang.framedCameraNutritionTitle,
        instructions: isFront
            ? lang.framedCameraFrontInstructions
            : lang.framedCameraNutritionInstructions,
        maxDimension: isFront ? 1024 : 1600,
      ),
    ),
  );
  return path == null
      ? const CameraPhotoCaptureResult.cancelled()
      : CameraPhotoCaptureResult.captured(path);
}
