import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

import '../../core/logger/logger.dart';
import 'background_removal_result.dart';

/// Removes only near-white pixels connected to the image border.
class ImageBackgroundRemover {
  const ImageBackgroundRemover();

  Future<BackgroundRemovalResult> remove(Uint8List bytes) async {
    try {
      final result = await compute(removeBorderWhiteBackground, bytes);
      return result.removed
          ? result
          : BackgroundRemovalResult(bytes: bytes, removed: false);
    } catch (error) {
      Log.w(
        'ImageBackgroundRemover',
        'Background removal failed: ${error.runtimeType}',
      );
      return BackgroundRemovalResult(bytes: bytes, removed: false);
    }
  }
}

BackgroundRemovalResult removeBorderWhiteBackground(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    return BackgroundRemovalResult(bytes: bytes, removed: false);
  }
  final bitmap = decoded.convert(format: image.Format.uint8, numChannels: 4);
  final width = bitmap.width;
  final height = bitmap.height;
  final pixelCount = width * height;
  final visited = Uint8List(pixelCount);
  final queue = Uint32List(pixelCount);
  var head = 0;
  var tail = 0;
  var removed = 0;

  void enqueue(int x, int y) {
    final index = y * width + x;
    if (visited[index] != 0) return;
    visited[index] = 1;
    final pixel = bitmap.getPixel(x, y);
    // Never cross a dark contour or colored food. Transparent pixels connect
    // the border to remaining white background but do not count as removal.
    if (pixel.a == 0 || (pixel.r >= 245 && pixel.g >= 245 && pixel.b >= 245)) {
      queue[tail++] = index;
    }
  }

  for (var x = 0; x < width; x++) {
    enqueue(x, 0);
    enqueue(x, height - 1);
  }
  for (var y = 0; y < height; y++) {
    enqueue(0, y);
    enqueue(width - 1, y);
  }
  while (head < tail) {
    final index = queue[head++];
    final x = index % width;
    final y = index ~/ width;
    final pixel = bitmap.getPixel(x, y);
    if (pixel.a != 0) removed++;
    bitmap.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 0);
    if (x > 0) enqueue(x - 1, y);
    if (x + 1 < width) enqueue(x + 1, y);
    if (y > 0) enqueue(x, y - 1);
    if (y + 1 < height) enqueue(x, y + 1);
  }
  // A missing/broken outline can expose the entire white subject. Keep the
  // original if nothing remains, rather than returning an empty image.
  if (removed == 0 || tail == pixelCount) {
    return BackgroundRemovalResult(bytes: bytes, removed: false);
  }
  return BackgroundRemovalResult(
    bytes: Uint8List.fromList(image.encodePng(bitmap)),
    removed: true,
  );
}
