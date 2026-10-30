import 'dart:ui';

Rect cameraFrameSelection(Size size, double frameAspectRatio) {
  final width = size.width * 0.9;
  final height = width / frameAspectRatio;
  final frame = height <= size.height * 0.85
      ? Size(width, height)
      : Size(size.height * 0.85 * frameAspectRatio, size.height * 0.85);
  return Rect.fromLTWH(
    (1 - frame.width / size.width) / 2,
    (1 - frame.height / size.height) / 2,
    frame.width / size.width,
    frame.height / size.height,
  );
}

Rect previewCropToPhoto(Rect crop, double previewAspectRatio, Size photoSize) {
  final photoAspectRatio = photoSize.aspectRatio;
  final visible = photoAspectRatio > previewAspectRatio
      ? Rect.fromLTWH(
          (1 - previewAspectRatio / photoAspectRatio) / 2,
          0,
          previewAspectRatio / photoAspectRatio,
          1,
        )
      : Rect.fromLTWH(
          0,
          (1 - photoAspectRatio / previewAspectRatio) / 2,
          1,
          photoAspectRatio / previewAspectRatio,
        );
  return Rect.fromLTWH(
    visible.left + crop.left * visible.width,
    visible.top + crop.top * visible.height,
    crop.width * visible.width,
    crop.height * visible.height,
  );
}
