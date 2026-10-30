import 'dart:typed_data';
import 'dart:ui';

import 'package:diabeatthis/core/media/photo_crop_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test(
    'saved JPEG matches the camera frame when preview is narrower than photo',
    () {
      final source = img.Image(width: 120, height: 160);
      img.fill(source, color: img.ColorRgb8(255, 0, 0));
      img.fillRect(
        source,
        x1: 20,
        y1: 0,
        x2: 99,
        y2: 159,
        color: img.ColorRgb8(0, 255, 0),
      );
      final bytes = cropPhotoBytes((
        bytes: Uint8List.fromList(img.encodePng(source)),
        crop: const Rect.fromLTWH(0, 0, 1, 1),
        maxDimension: 1600,
        previewAspectRatio: 0.5,
      ));
      final result = img.decodeJpg(bytes)!;
      expect(result.width, 80);
      expect(result.height, 160);
      expect(result.getPixel(0, 80).g, greaterThan(240));
      expect(result.getPixel(79, 80).g, greaterThan(240));
    },
  );

  test('whole photo mode preserves areas outside the preview crop', () {
    final bytes = cropPhotoBytes((
      bytes: Uint8List.fromList(
        img.encodePng(img.Image(width: 120, height: 160)),
      ),
      crop: const Rect.fromLTWH(0, 0, 1, 1),
      maxDimension: 1600,
      previewAspectRatio: null,
    ));
    final result = img.decodeJpg(bytes)!;
    expect(result.width, 120);
    expect(result.height, 160);
  });
}
