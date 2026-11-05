import 'package:diabeatthis/common/meal/review_recorded_meal_conversion_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/recorded_portion_meal_fixture.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;
  late ReviewRecordedMealConversionUseCase useCase;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    await db.withRecordedFactsPreserved(() async {
      await seedRecordedPortionMeal(db);
    });
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    useCase = container.read(reviewRecordedMealConversionUseCaseProvider);
  });

  test(
    'loading missing conversions is scoped to the meal and never writes suggestions',
    () async {
      final requests = await useCase.load(1);
      expect(requests, hasLength(1));
      expect(requests.single.mealId, 1);
      expect(requests.single.ingredientName, 'Bread');
      expect(requests.single.portionName, 'Slice');
      expect(requests.single.currentGrams, 30);
      expect(await useCase.load(999), isEmpty);
      final entry = await (db.select(
        db.mealIngredients,
      )..where((row) => row.id.equals(requests.single.entryId))).getSingle();
      expect(entry.gramsPerPortionUsed, isNull);
    },
  );

  test(
    'confirmed historical weight persists without changing quantities or current mapping',
    () async {
      final request = (await useCase.load(1)).single;
      final before = await (db.select(
        db.mealIngredients,
      )..where((row) => row.id.equals(request.entryId))).getSingle();

      await useCase.confirm({request: 32.5});

      final after = await (db.select(
        db.mealIngredients,
      )..where((row) => row.id.equals(request.entryId))).getSingle();
      expect(after.gramsPerPortionUsed, 32.5);
      expect(after.amount, before.amount);
      expect(after.consumedAmount, before.consumedAmount);
      expect(
        (await db.select(db.ingredientPortions).getSingle()).gramsPerPortion,
        30,
      );
      expect(await useCase.load(1), isEmpty);
      await expectLater(useCase.confirm({request: 60}), throwsStateError);
      expect(
        (await (db.select(
              db.mealIngredients,
            )..where((row) => row.id.equals(request.entryId))).getSingle())
            .gramsPerPortionUsed,
        32.5,
      );
    },
  );

  test(
    'invalid reviewed weights propagate validation errors without recording a conversion',
    () async {
      final request = (await useCase.load(1)).single;
      for (final weight in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(
          useCase.confirm({request: weight}),
          throwsArgumentError,
        );
      }
      expect((await useCase.load(1)).single.entryId, request.entryId);
    },
  );
}
