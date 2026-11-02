import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/add_meal_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/meal_flow_test_fixture.dart';

void main() {
  test(
    'controller prepares the name, requires category and blocks duplicate saves',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final draftSubscription = container.listen(mealDraftProvider, (_, _) {});
      addTearDown(draftSubscription.close);
      final controllerSubscription = container.listen(
        addMealControllerProvider,
        (_, _) {},
      );
      addTearDown(controllerSubscription.close);
      await container.read(addMealControllerProvider.future);
      final draft = container.read(mealDraftProvider.notifier);
      draft.setMealIngredients([mealFlowIngredient(container)]);
      final controller = container.read(addMealControllerProvider.notifier);
      await expectLater(controller.saveCurrentDraft(lang), throwsArgumentError);
      expect(await db.select(db.meal).get(), isEmpty);
      draft.setCategory(MealCategory.lunch);
      final operation = controller.saveCurrentDraft(lang);
      await expectLater(controller.saveCurrentDraft(lang), throwsStateError);
      final saved = await operation;
      expect(saved.name, '${MealCategory.lunch.label(lang)}: Oatmeal');
      expect(saved.category, MealCategory.lunch);
      expect(await db.select(db.meal).get(), hasLength(1));
    },
  );
}
