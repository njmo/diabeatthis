import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/quick_low_treatment_items_controller.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../common/ai/helpers/paused_ingredient_write.dart';

void main() {
  test(
    'shortcut save survives provider cleanup during an ingredient write',
    () async {
      final gate = PausedIngredientWrite();
      final db = DatabaseImpl(NativeDatabase.memory().interceptWith(gate));
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        if (!gate.resume.isCompleted) gate.resume.complete();
        container.dispose();
        await db.close();
      });
      final controller = container.read(
        quickLowTreatmentItemsControllerProvider.notifier,
      );
      final saving = controller.upsertSlot(
        slot: 1,
        mealIngredient: const MealIngredientsDraft(
          ingredient: IngredientDraft.draft(
            name: 'Juice',
            carbsPer100g: 10,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 1,
            isReference: false,
            iconAssetPath: 'assets/icons/food/prepared_meal.png',
          ),
          ingredientPortion: IngredientPortionDraft(
            portion: PortionSelection.draft(name: 'glass', unitHint: 'g'),
            amount: 200,
          ),
          amount: 0.5,
          quantityConfidence: 1,
          entryType: 'planned',
          consumedAmount: null,
          consumedConfidence: null,
        ),
      );
      await gate.reached.future.timeout(const Duration(seconds: 5));
      await container.pump();
      gate.resume.complete();
      await saving.timeout(const Duration(seconds: 5));

      final items = await db.quickLowTreatmentItemDao
          .getQuickLowTreatmentItems();
      expect(items, hasLength(1));
      expect(items.single.name, 'Juice');
      expect(items.single.amount, 0.5);
      expect(items.single.gramsPerPortion, 200);
    },
  );
}
