import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'camera_crop_geometry.dart';

class PhotoCropService {
  const PhotoCropService();

  Future<String> prepare(
    String path,
    Rect crop,
    int maxDimension, {
    double? previewAspectRatio,
  }) async {
    final bytes = await File(path).readAsBytes();
    final result = await compute(cropPhotoBytes, (
      previewAspectRatio: previewAspectRatio,
      bytes: bytes,
      crop: crop,
      maxDimension: maxDimension,
    ));
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/scan_crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(result, flush: true);
    return file.path;
  }
}

Uint8List cropPhotoBytes(
  ({Uint8List bytes, Rect crop, int maxDimension, double? previewAspectRatio})
  input,
) {
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) {
    throw const FormatException('Cannot decode photo.');
  }
  final image = img.bakeOrientation(decoded);
  final ratio = input.previewAspectRatio;
  final crop = ratio == null
      ? input.crop
      : previewCropToPhoto(
          input.crop,
          ratio,
          Size(image.width.toDouble(), image.height.toDouble()),
        );
  final maxDimension = input.maxDimension;
  final x = (crop.left * image.width).round().clamp(0, image.width - 1);
  final y = (crop.top * image.height).round().clamp(0, image.height - 1);
  final width = (crop.width * image.width).round().clamp(1, image.width - x);
  final height = (crop.height * image.height).round().clamp(
    1,
    image.height - y,
  );
  var cropped = img.copyCrop(image, x: x, y: y, width: width, height: height);
  if (math.max(width, height) > maxDimension) {
    cropped = img.copyResize(
      cropped,
      width: width >= height ? maxDimension : null,
      height: height > width ? maxDimension : null,
      interpolation: img.Interpolation.average,
    );
  }
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 85));
}
