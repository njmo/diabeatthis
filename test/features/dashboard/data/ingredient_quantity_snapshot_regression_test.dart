import 'package:diabeatthis/common/nutrition/confidence_level.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await db.customInsert(
      "INSERT INTO meal (id,name,planned_at) VALUES (901,'Regression meal',1793520000000)",
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  for (final example in [
    (
      name: 'stored piece',
      amount: 1.5,
      portion: true,
      reference: false,
      expectedGrams: 225.0,
    ),
    (
      name: 'direct grams',
      amount: 225.0,
      portion: false,
      reference: false,
      expectedGrams: 225.0,
    ),
    (
      name: 'reference portion',
      amount: 1.5,
      portion: false,
      reference: true,
      expectedGrams: 150.0,
    ),
  ]) {
    test(
      '${example.name} retains nutrition and combined confidence in the planned analysis',
      () async {
        await db.customStatement(
          '''INSERT INTO ingredient
        (id,name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,carbs_label_mode,nutrition_confidence,is_reference)
        VALUES (901,'Regression ingredient',40,10,5,20,'eu',0.75,?)''',
          [example.reference ? 1 : 0],
        );
        if (example.portion) {
          await db.customInsert(
            "INSERT INTO portion (id,name,unit_hint) VALUES (901,'Regression piece','g')",
          );
          await db.customInsert(
            'INSERT INTO ingredient_portions (ingredient_id,portion_id,grams_per_portion) VALUES (901,901,150)',
          );
        }
        await db.customStatement(
          '''INSERT INTO meal_ingredients
        (id,meal_id,ingredient_id,portion_id,amount,quantity_confidence)
        VALUES (901,901,901,?,?,0.5)''',
          [example.portion ? 901 : null, example.amount],
        );

        final drafts = await container.read(
          getMealIngredientsDraftForMealProvider(901).future,
        );
        expect(drafts.single.amount, example.amount);
        expect(drafts.single.quantityConfidence, 0.5);
        expect(drafts.single.ingredient.nutritionConfidence, 0.75);
        if (example.portion) {
          expect(drafts.single.ingredientPortion.amount, 150);
        }
        if (example.reference) {
          expect(drafts.single.ingredient.isReference, isTrue);
        }

        await container
            .read(mealSnapshotControllerProvider)
            .createPlannedSnapshot(901);
        final snapshot = (await db.select(db.mealSnapshot).get()).single;
        expect(snapshot.totalGrams, example.expectedGrams);
        expect(
          snapshot.totalNetCarbsG,
          closeTo(example.expectedGrams * 0.4, 0.000001),
        );
        expect(
          snapshot.totalProteinG,
          closeTo(example.expectedGrams * 0.2, 0.000001),
        );
        expect(
          snapshot.totalFatG,
          closeTo(example.expectedGrams * 0.1, 0.000001),
        );
        expect(
          snapshot.totalCaloriesKcal,
          closeTo(example.expectedGrams * 3.3, 0.000001),
        );
        expect(
          snapshot.carbWeightedEffectiveConfidence,
          closeTo(0.6123724356957945, 1e-12),
        );
        expect(
          snapshot.wbtWeightedEffectiveConfidence,
          closeTo(0.6123724356957945, 1e-12),
        );
        expect(
          ConfidenceLevelX.fromDouble01(
            snapshot.carbWeightedEffectiveConfidence!,
          ),
          ConfidenceLevel.medium,
        );
      },
    );
  }
}
