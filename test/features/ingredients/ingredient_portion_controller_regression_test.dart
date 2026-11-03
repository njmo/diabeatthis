import 'dart:async';

import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/domain/use_cases/load_ingredient_details_use_case.dart';
import 'package:diabeatthis/features/ingredients/data/domain/use_cases/update_ingredient_details_use_case.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_details_data.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_portion_data.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_details_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/scripted_load_ingredient_details_use_case.dart';
import '../../helpers/regression/scripted_read.dart';
import '../../helpers/regression/scripted_update_ingredient_portion_use_case.dart';

void main() {
  for (final failFirst in [false, true]) {
    test(
      'portion editor retains facts while saving, blocks duplicate writes and supports retry: failure=$failFirst',
      () async {
        final ingredient = Ingredient(
          id: 17,
          name: 'Bread',
          carbsPer100g: 50,
          fatPer100g: 4,
          fiberPer100g: 8,
          proteinPer100g: 10,
          nutritionConfidence: .9,
          isReference: false,
          carbsLabelMode: CarbsLabelMode.eu,
        );
        final original = IngredientDetailsData(
          ingredient: ingredient,
          portions: [
            IngredientPortionData(
              portionId: 4,
              name: 'Slice',
              unitHint: 'piece',
              gramsPerPortion: 30,
            ),
            IngredientPortionData(
              portionId: 5,
              name: 'Loaf',
              unitHint: 'piece',
              gramsPerPortion: 500,
            ),
          ],
          usages: [],
          history: [],
        );
        final pending = Completer<void>();
        final load = ScriptedRead<IngredientDetailsData>('details', [
          (arguments: [17], respond: () => original),
        ]);
        final writes = ScriptedRead<void>('portion update', [
          (arguments: [17, 4, 40.0], respond: () => pending.future),
          if (failFirst) (arguments: [17, 4, 40.0], respond: () {}),
        ]);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWith(
              (ref) => throw StateError('Unexpected direct database read'),
            ),
            loadIngredientDetailsUseCaseProvider.overrideWithValue(
              ScriptedLoadIngredientDetailsUseCase(load),
            ),
            updateIngredientDetailsUseCaseProvider.overrideWithValue(
              ScriptedUpdateIngredientPortionUseCase(writes),
            ),
          ],
        );
        addTearDown(container.dispose);
        final provider = ingredientDetailsControllerProvider(17);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        await container.read(provider.future);
        final controller = container.read(provider.notifier);
        final operation = controller.updatePortionAmount(
          portionId: 4,
          gramsPerPortion: 40,
        );
        expect(container.read(provider).requireValue.isSaving, true);
        expect(
          container
              .read(provider)
              .requireValue
              .data
              .portions
              .first
              .gramsPerPortion,
          30,
        );
        await controller.updatePortionAmount(portionId: 4, gramsPerPortion: 99);
        expect(writes.calls, [
          [17, 4, 40.0],
        ]);
        if (failFirst) {
          final error = StateError('Write failed');
          final expectation = expectLater(operation, throwsA(same(error)));
          pending.completeError(error);
          await expectation;
          expect(container.read(provider).requireValue.isSaving, false);
          expect(container.read(provider).requireValue.data, same(original));
          await controller.updatePortionAmount(
            portionId: 4,
            gramsPerPortion: 40,
          );
        } else {
          pending.complete();
          await operation;
        }
        final result = container.read(provider).requireValue;
        expect(result.isSaving, false);
        expect(result.data.portions.map((p) => p.gramsPerPortion), [40, 500]);
        expect(result.data.ingredient, same(ingredient));
        expect(original.portions.first.gramsPerPortion, 30);
        load.verifyComplete();
        writes.verifyComplete();
      },
    );
  }
}
