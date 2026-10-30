import 'dart:typed_data';

import 'package:diabeatthis/common/images/image_background_remover.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

image.Image outlinedWhiteFood({int background = 255}) {
  final bitmap = image.Image(width: 32, height: 32, numChannels: 4);
  image.fill(
    bitmap,
    color: image.ColorRgba8(background, background, background, 255),
  );
  image.fillRect(
    bitmap,
    x1: 8,
    y1: 8,
    x2: 23,
    y2: 23,
    color: image.ColorRgba8(0, 0, 0, 255),
  );
  image.fillRect(
    bitmap,
    x1: 10,
    y1: 10,
    x2: 21,
    y2: 21,
    color: image.ColorRgba8(255, 255, 255, 255),
  );
  return bitmap;
}

void main() {
  for (final background in [255, 248]) {
    test(
      'removes edge white ($background) while preserving white food and its black outline',
      () async {
        final original = Uint8List.fromList(
          image.encodePng(outlinedWhiteFood(background: background)),
        );
        final result = await const ImageBackgroundRemover().remove(original);
        expect(result.removed, isTrue);
        final decoded = image.decodePng(result.bytes)!;
        expect(decoded.getPixel(0, 0).a, 0);
        final food = decoded.getPixel(16, 16);
        expect([food.r, food.g, food.b, food.a], [255, 255, 255, 255]);
        final outline = decoded.getPixel(8, 8);
        expect([outline.r, outline.g, outline.b, outline.a], [0, 0, 0, 255]);
      },
    );
  }

  test('preserves colored pixels connected to the image edge', () async {
    final bitmap = outlinedWhiteFood();
    bitmap.setPixelRgba(0, 16, 220, 20, 20, 255);
    final result = await const ImageBackgroundRemover().remove(
      Uint8List.fromList(image.encodePng(bitmap)),
    );
    expect(image.decodePng(result.bytes)!.getPixel(0, 16).a, 255);
  });

  test('an all-white image or invalid input keeps the original', () async {
    final bitmap = image.Image(width: 32, height: 32, numChannels: 4);
    image.fill(bitmap, color: image.ColorRgba8(255, 255, 255, 255));
    for (final bytes in [
      Uint8List.fromList(image.encodePng(bitmap)),
      Uint8List(0),
    ]) {
      final result = await const ImageBackgroundRemover().remove(bytes);
      expect(result.removed, isFalse);
      expect(result.bytes, same(bytes));
    }
  });

  test('already transparent background remains unchanged', () async {
    final bitmap = outlinedWhiteFood();
    for (final pixel in bitmap) {
      if (pixel.x < 8 || pixel.x > 23 || pixel.y < 8 || pixel.y > 23) {
        pixel.a = 0;
      }
    }
    final bytes = Uint8List.fromList(image.encodePng(bitmap));
    final result = await const ImageBackgroundRemover().remove(bytes);
    expect(result.removed, isFalse);
    expect(result.bytes, same(bytes));
  });
}
