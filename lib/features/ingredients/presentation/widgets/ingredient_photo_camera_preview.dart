import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../common/widgets/camera_frame_mask.dart';

class IngredientPhotoCameraPreview extends StatelessWidget {
  final CameraController controller;
  final Rect selection;

  const IngredientPhotoCameraPreview({
    super.key,
    required this.controller,
    required this.selection,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / controller.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            CameraFrameMask(selection: selection),
          ],
        ),
      ),
    );
  }
}
