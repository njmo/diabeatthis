import 'dart:typed_data';
import 'dart:ui';

import 'package:diabeatthis/core/media/photo_crop_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('crops the selected region and encodes it as JPEG', () {
    final source = img.Image(width: 100, height: 100);
    img.fill(source, color: img.ColorRgb8(255, 0, 0));
    img.fillRect(
      source,
      x1: 50,
      y1: 0,
      x2: 99,
      y2: 99,
      color: img.ColorRgb8(0, 255, 0),
    );
    final bytes = cropPhotoBytes((
      bytes: Uint8List.fromList(img.encodePng(source)),
      crop: const Rect.fromLTWH(0.5, 0, 0.5, 1),
      maxDimension: 1600,
      previewAspectRatio: null,
    ));
    final result = img.decodeJpg(bytes)!;
    expect(result.width, 50);
    expect(result.height, 100);
    expect(result.getPixel(25, 50).g, greaterThan(240));
    expect(result.getPixel(25, 50).r, lessThan(15));
  });

  test(
    'limits the longer side of portrait photos without changing aspect ratio',
    () {
      final bytes = cropPhotoBytes((
        bytes: Uint8List.fromList(
          img.encodePng(img.Image(width: 200, height: 400)),
        ),
        crop: const Rect.fromLTWH(0, 0, 1, 1),
        maxDimension: 100,
        previewAspectRatio: null,
      ));
      final result = img.decodeJpg(bytes)!;
      expect(result.width, 50);
      expect(result.height, 100);
    },
  );

  test('does not upscale a small whole photo', () {
    final bytes = cropPhotoBytes((
      bytes: Uint8List.fromList(
        img.encodePng(img.Image(width: 80, height: 40)),
      ),
      crop: const Rect.fromLTWH(0, 0, 1, 1),
      maxDimension: 1024,
      previewAspectRatio: null,
    ));
    final result = img.decodeJpg(bytes)!;
    expect(result.width, 80);
    expect(result.height, 40);
  });

  test('applies camera EXIF rotation before cropping', () {
    final source = img.Image(width: 100, height: 50);
    source.exif.imageIfd.orientation = 6;
    final bytes = cropPhotoBytes((
      bytes: Uint8List.fromList(img.encodeJpg(source)),
      crop: const Rect.fromLTWH(0, 0, 1, 0.5),
      maxDimension: 1600,
      previewAspectRatio: null,
    ));
    final result = img.decodeJpg(bytes)!;
    expect(result.width, 50);
    expect(result.height, 50);
  });

  test('rejects undecodable input', () {
    expect(
      () => cropPhotoBytes((
        bytes: Uint8List(0),
        crop: const Rect.fromLTWH(0, 0, 1, 1),
        maxDimension: 1600,
        previewAspectRatio: null,
      )),
      throwsFormatException,
    );
  });
}
