import 'dart:io';

import 'package:diabeatthis/features/ingredients/data/icons/food_icon_generation_provider.dart';
import 'package:diabeatthis/features/ingredients/data/icons/food_icon_generation_result.dart';
import 'package:diabeatthis/features/ingredients/data/icons/food_icon_generation_service.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_icon_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

class ReadyFoodImageService extends FoodIconGenerationService {
  ReadyFoodImageService(this.result);

  final FoodIconGenerationResult result;

  @override
  Future<FoodIconGenerationResult> run(String name) async => result;
}

void main() {
  testWidgets(
    'accepted generation is returned for cleanup after picker disposal',
    (tester) async {
      final folder = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('abandoned-food-preview'),
      ))!;
      addTearDown(() => folder.delete(recursive: true));
      final file = (await tester.runAsync(
        () => File(
          'assets/icons/food/apple.png',
        ).copy('${folder.path}/preview.png'),
      ))!;
      final service = ReadyFoodImageService(
        FoodIconGenerationResult(
          file: file,
          path: 'local-images/generated/preview.png',
          generationTime: Duration.zero,
          saveTime: Duration.zero,
          byteCount: 100,
        ),
      );
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      String? abandoned;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodIconGenerationServiceProvider.overrideWithValue(service),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder(
                valueListenable: visible,
                builder: (context, show, child) => show
                    ? IngredientIconPicker(
                        name: 'Apple',
                        onAbandonedSelection: (path) => abandoned = path,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Generuj przez AI'));
      await tester.pumpAndSettle();
      visible.value = false;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Użyj obrazka'));
      await tester.pumpAndSettle();
      expect(abandoned, 'local-images/generated/preview.png');
      expect(tester.takeException(), isNull);
    },
  );
}
