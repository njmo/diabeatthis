import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/clients/open_food_facts_product_client.dart';
import 'package:diabeatthis/features/ingredients/data/providers/open_food_facts_product_client_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_barcode_lookup_controller.dart';
import 'package:diabeatthis/features/ingredients/presentation/models/ingredient_barcode_scan_outcome.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SelectionOffClient extends OpenFoodFactsProductClient {
  SelectionOffClient(this.name);
  final String? name;
  @override
  Future<Map<String, dynamic>> fetchProduct(String barcode) async => {
    'status': 1,
    'product': {
      'product_name': name,
      'brands': 'Brand B',
      'nutriments': {
        'carbohydrates_100g': 5,
        'fiber_100g': 0,
        'fat_100g': 3,
        'proteins_100g': 8,
      },
    },
  };
}

void main() {
  for (final name in [null, 'Yogurt']) {
    test(
      'selection preserves OFF facts without name and never reuses another brand: $name',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            openFoodFactsProductClientProvider.overrideWithValue(
              SelectionOffClient(name),
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        await db
            .into(db.ingredient)
            .insert(
              IngredientCompanion.insert(
                name: 'Yogurt',
                brand: const Value('Brand A'),
                carbsLabelMode: const Value('eu'),
                carbsPer100g: 5,
                fiberPer100g: 0,
                fatPer100g: 3,
                proteinPer100g: 8,
                nutritionConfidence: .8,
              ),
            );
        final subscription = container.listen(
          ingredientBarcodeLookupControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final outcome = await container
            .read(ingredientBarcodeLookupControllerProvider.notifier)
            .scanForSelection('5901234123457');
        expect(
          outcome.type,
          name == null
              ? IngredientBarcodeScanOutcomeType.needsReview
              : IngredientBarcodeScanOutcomeType.newDraft,
        );
        expect(outcome.draft?.carbsPer100g, 5);
        expect(outcome.draft?.proteinPer100g, 8);
        expect(outcome.draft?.brand, 'Brand B');
        final rows = await db.select(db.ingredient).get();
        expect(rows, hasLength(1));
        expect(rows.single.barcode, isNull);
      },
    );
  }
}
