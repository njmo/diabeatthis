import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_filter_item.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_filter_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'required ingredients survive removal and reset; added identities stay unique',
    () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('Filtering must not read the database'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        ingredientFilterProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(ingredientFilterProvider.notifier);
      const required = IngredientFilterItem(
        id: 1,
        name: 'Rice',
        removable: false,
      );
      const optional = IngredientFilterItem(
        id: 2,
        name: 'Potato',
        removable: false,
      );
      controller.overrideItems([required]);
      controller.addIngredient(optional);
      controller.addIngredient(optional.copyWith(removable: true));
      expect(container.read(ingredientFilterProvider), [
        required,
        optional.copyWith(removable: true),
      ]);
      controller.removeIngredient(1);
      expect(container.read(ingredientFilterProvider), hasLength(2));
      controller.removeIngredient(999);
      expect(container.read(ingredientFilterProvider), hasLength(2));
      controller.clearAdditionalIngredients();
      expect(container.read(ingredientFilterProvider), [required]);
      controller.addIngredient(optional);
      controller.removeIngredient(2);
      expect(container.read(ingredientFilterProvider), [required]);
    },
  );
}
