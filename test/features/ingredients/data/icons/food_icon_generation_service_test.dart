import 'dart:io';
import 'dart:ui';

import 'package:diabeatthis/features/ingredients/data/icons/food_icon_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'one generation produces a persistent 256px PNG with separate timings',
    () async {
      final folder = await Directory.systemTemp.createTemp('food-icon-test-');
      addTearDown(() => folder.delete(recursive: true));
      var calls = 0;
      final service = FoodIconGenerationService(
        generate: (prompt) async {
          calls++;
          expect(prompt, contains('Gołąbki bez zawijania'));
          return File(
            'assets/icons/wicked_food/flour-tortillas.webp',
          ).readAsBytes();
        },
        directory: () async => folder,
      );
      final result = await service.run('Gołąbki bez zawijania');
      expect(calls, 1);
      expect(result.file.existsSync(), isTrue);
      final bytes = await result.file.readAsBytes();
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(result.byteCount, bytes.length);
      expect(result.generationTime.isNegative, isFalse);
      expect(result.saveTime.isNegative, isFalse);
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 256);
      expect(frame.image.height, 256);
      frame.image.dispose();
      codec.dispose();
    },
  );

  test('a failed generation does not save an empty file', () async {
    final folder = await Directory.systemTemp.createTemp('food-icon-failure-');
    addTearDown(() => folder.delete(recursive: true));
    final service = FoodIconGenerationService(
      generate: (_) async => throw StateError('AI unavailable'),
      directory: () async => folder,
    );
    await expectLater(service.run('Gołąbki'), throwsStateError);
    expect(folder.listSync(), isEmpty);
  });
}
