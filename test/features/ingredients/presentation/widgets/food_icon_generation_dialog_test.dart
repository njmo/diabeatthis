import 'dart:async';
import 'dart:io';

import 'package:diabeatthis/features/ingredients/data/icons/food_icon_generation_provider.dart';
import 'package:diabeatthis/features/ingredients/data/icons/food_icon_generation_result.dart';
import 'package:diabeatthis/features/ingredients/data/icons/food_icon_generation_service.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/food_icon_generation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

class PendingFoodImageService extends FoodIconGenerationService {
  final completion = Completer<FoodIconGenerationResult>();
  @override
  Future<FoodIconGenerationResult> run(String name) => completion.future;
}

void main() {
  for (final accept in [true, false]) {
    testWidgets(
      'generated image is ${accept ? 'retained only after accepting the preview' : 'deleted if generation finishes after canceling'}',
      (tester) async {
        final folder = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('food-preview-'),
        ))!;
        addTearDown(() async => folder.delete(recursive: true));
        final file = File('${folder.path}/preview.png');
        await tester.runAsync(
          () => File('assets/icons/food/apple.png').copy(file.path),
        );
        final service = PendingFoodImageService();
        String? chosen;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              foodIconGenerationServiceProvider.overrideWithValue(service),
            ],
            child: localizedMaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      chosen = await showDialog<String>(
                        context: context,
                        builder: (_) =>
                            const FoodIconGenerationDialog(name: 'Apple'),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        if (!accept) {
          await tester.tap(find.text('Anuluj'));
          await tester.pumpAndSettle();
        }
        service.completion.complete(
          FoodIconGenerationResult(
            file: file,
            path: 'local-images/generated/preview.png',
            generationTime: const Duration(seconds: 7),
            saveTime: const Duration(milliseconds: 20),
            byteCount: 100,
          ),
        );
        await tester.pump();
        if (accept) {
          await tester.pumpAndSettle();
          await tester.tap(find.text('Użyj obrazka'));
          await tester.pumpAndSettle();
          expect(chosen, 'local-images/generated/preview.png');
        } else {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          expect(chosen, isNull);
        }
        expect(await tester.runAsync(file.exists), accept);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
