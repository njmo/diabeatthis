import 'dart:io';
import 'dart:typed_data';

import 'package:diabeatthis/features/ingredients/data/icons/food_icon_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'generated white food keeps its alpha in saved PNG and can retain the original instead',
    () async {
      final folder = await Directory.systemTemp.createTemp('food-alpha-');
      addTearDown(() => folder.delete(recursive: true));
      final original = image.Image(width: 32, height: 32, numChannels: 4);
      image.fill(original, color: image.ColorRgba8(255, 255, 255, 255));
      image.fillRect(
        original,
        x1: 6,
        y1: 6,
        x2: 25,
        y2: 25,
        color: image.ColorRgba8(0, 0, 0, 255),
      );
      image.fillRect(
        original,
        x1: 8,
        y1: 8,
        x2: 23,
        y2: 23,
        color: image.ColorRgba8(255, 255, 255, 255),
      );
      final result = await FoodIconGenerationService(
        generate: (_) async => Uint8List.fromList(image.encodePng(original)),
        directory: () async => folder,
      ).run('Jogurt');
      expect(result.backgroundRemoved, isTrue);
      final stored = image.decodePng(await result.file.readAsBytes())!;
      expect(stored.getPixel(0, 0).a, 0);
      final food = stored.getPixel(128, 128);
      expect([food.r, food.g, food.b, food.a], [255, 255, 255, 255]);
      final savedOriginal = image.decodePng(
        await result.originalFile!.readAsBytes(),
      )!;
      expect(savedOriginal.getPixel(0, 0).a, 255);
      await result.discardUnused(keepPath: result.originalPath);
      expect(await result.file.exists(), isFalse);
      expect(await result.originalFile!.exists(), isTrue);
    },
  );
}
