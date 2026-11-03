import 'dart:async';

import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meal_summary/data/models/meal_summary_data.dart';
import 'package:diabeatthis/features/meal_summary/data/models/meal_summary_item.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/load_meal_summary_data_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/regression/scripted_finalize_meal_summary_use_case.dart';
import '../../../../helpers/regression/scripted_load_meal_summary_use_case.dart';
import '../../../../helpers/regression/scripted_read.dart';

void main() {
  late ProviderContainer container;
  late ScriptedRead<MealSummaryData> loads;
  late ScriptedRead<void> writes;
  setUp(() {
    writes = ScriptedRead<void>('finalize', []);
    loads = ScriptedRead<MealSummaryData>('summary', [
      (
        arguments: [7],
        respond: () => MealSummaryData(
          mealId: 7,
          mealStatus: 'eating',
          items: [
            MealSummaryItem(
              id: 11,
              name: 'Bread',
              portion: null,
              isReference: false,
              plannedAmount: 100,
              reportedAmount: 80,
              consumedAmount: 80,
              consumedConfidence: .7,
              netCarbsPerAmount: .42,
              gramsPerAmount: 1,
              carbsPerAmount: .5,
              fiberPerAmount: .08,
              fatPerAmount: .04,
              proteinPerAmount: .1,
            ),
          ],
        ),
      ),
    ]);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => throw StateError('Controller must delegate database work'),
        ),
        finalizeMealSummaryUseCaseProvider.overrideWithValue(
          ScriptedFinalizeMealSummaryUseCase(writes),
        ),
        loadMealSummaryDataUseCaseProvider.overrideWithValue(
          ScriptedLoadMealSummaryUseCase(loads),
        ),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    loads.verifyComplete();
    writes.verifyComplete();
  });

  test(
    'portion factor is based on reported consumption and never compounds previous edits',
    () async {
      final provider = mealSummaryControllerProvider(7);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      final controller = container.read(provider.notifier);
      controller.setReportedPortionFactor(.5);
      expect(
        container.read(provider).requireValue.itemsById[11]!.consumedAmount,
        40,
      );
      controller.setReportedPortionFactor(.25);
      final item = container.read(provider).requireValue.itemsById[11]!;
      expect(item.consumedAmount, 20);
      expect(item.plannedAmount, 100);
      expect(item.reportedAmount, 80);
      expect(
        item.netCarbsPerAmount * item.consumedAmount,
        closeTo(8.4, .00001),
      );
      expect(item.consumedConfidence, .7);
      expect(initial.itemsById[11]!.consumedAmount, 80);
      controller.setReportedPortionFactor(0);
      expect(
        container.read(provider).requireValue.itemsById[11]!.consumedAmount,
        0,
      );
    },
  );

  test(
    'invalid factors and unknown item IDs cannot corrupt the draft',
    () async {
      final provider = mealSummaryControllerProvider(7);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      final controller = container.read(provider.notifier);
      for (final value in [
        -1.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        controller.setReportedPortionFactor(value);
        expect(container.read(provider).requireValue, same(initial));
      }
      controller.setConsumedAmount(999, 100);
      controller.setConsumedConfidence(999, .8);
      expect(container.read(provider).requireValue, same(initial));
      controller.setConsumedAmount(11, -5);
      controller.setConsumedConfidence(11, .9);
      final item = container.read(provider).requireValue.itemsById[11]!;
      expect(item.consumedAmount, 0);
      expect(item.consumedConfidence, .9);
      expect(item.reportedAmount, 80);
    },
  );

  for (final mode in MealSummarySaveMode.values) {
    for (final failure in [false, true]) {
      test(
        'save delegates the exact reviewed draft and mode=$mode; failure=$failure',
        () async {
          final provider = mealSummaryControllerProvider(7);
          final subscription = container.listen(provider, (_, _) {});
          addTearDown(subscription.close);
          await container.read(provider.future);
          final controller = container.read(provider.notifier);
          controller.setConsumedAmount(11, 60);
          final reviewed = container.read(provider).requireValue;
          final pending = Completer<void>();
          writes.steps.add((
            arguments: [reviewed, mode],
            respond: () => pending.future,
          ));
          final operation = controller.saveSummary(mode: mode);
          expect(container.read(provider).isLoading, true);
          if (failure) {
            final error = StateError('Save failed');
            final expectation = expectLater(operation, throwsA(same(error)));
            pending.completeError(error);
            await expectation;
            expect(container.read(provider).error, same(error));
          } else {
            pending.complete();
            await operation;
            expect(container.read(provider).requireValue, same(reviewed));
          }
          writes.verifyComplete();
        },
      );
    }
  }
  test(
    'extra items can be replaced and removed without changing recorded ingredients',
    () async {
      final provider = mealSummaryControllerProvider(7);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      final controller = container.read(provider.notifier);
      const extra = MealIngredientsDraft(
        ingredient: IngredientDraft.existing(
          id: 22,
          name: 'Oil',
          carbsPer100g: 0,
          fatPer100g: 100,
          fiberPer100g: 0,
          proteinPer100g: 0,
          nutritionConfidence: 1,
          isReference: false,
        ),
        ingredientPortion: IngredientPortionDraft(
          portion: PortionSelection.empty(),
          amount: 1,
        ),
        amount: 5,
        quantityConfidence: .8,
        entryType: 'extra',
        consumedAmount: 5,
        consumedConfidence: .8,
      );
      final replacement = extra.copyWith(amount: 10, consumedAmount: 10);
      final unrelated = extra.copyWith(amount: 2, consumedAmount: 2);
      controller.addExtraItem(extra);
      controller.addExtraItem(unrelated);
      controller.replaceExtraItem(extra, replacement);
      expect(container.read(provider).requireValue.extraItems, [
        replacement,
        unrelated,
      ]);
      expect(
        container.read(provider).requireValue.itemsById,
        same(initial.itemsById),
      );
      controller.removeExtraItem(replacement);
      expect(container.read(provider).requireValue.extraItems, [unrelated]);
      controller.setReportedPortionFactor(.5);
      expect(container.read(provider).requireValue.extraItems, [unrelated]);
      controller.setReportedPortionFactor(.25, clearExtras: true);
      expect(container.read(provider).requireValue.extraItems, isEmpty);
      expect(
        container.read(provider).requireValue.itemsById[11]!.consumedAmount,
        20,
      );
    },
  );

  test(
    'preparing an add-on restores reported amounts and applies a fresh confidence to an increase',
    () async {
      final provider = mealSummaryControllerProvider(7);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      final controller = container.read(provider.notifier);
      controller.setConsumedAmount(11, 20);
      controller.prepareAddOn();
      expect(
        container.read(provider).requireValue.itemsById[11]!.consumedAmount,
        80,
      );
      expect(
        container.read(provider).requireValue.itemsById[11]!.consumedConfidence,
        .7,
      );
      controller.prepareAddOn(totalMultiplier: 1.5);
      final item = container.read(provider).requireValue.itemsById[11]!;
      expect(item.consumedAmount, 150);
      expect(item.reportedAmount, 80);
      expect(item.plannedAmount, 100);
      expect(item.consumedConfidence, .75);
    },
  );
}
