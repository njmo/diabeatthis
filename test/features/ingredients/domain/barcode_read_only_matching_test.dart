import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/ingredients/data/domain/use_cases/find_ingredient_by_barcode_use_case.dart';
import 'package:diabeatthis/features/ingredients/data/domain/use_cases/find_matching_ingredient_for_scan_result_use_case.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/ingredients/domain/services/ingredient_matcher.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final existingCode in [null, '4006381333931']) {
    test(
      'read-only matching never attaches or replaces barcode $existingCode',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final id = await db
            .into(db.ingredient)
            .insert(
              IngredientCompanion.insert(
                name: 'Yogurt',
                carbsLabelMode: const Value('eu'),
                brand: const Value('Brand'),
                barcode: Value(existingCode),
                carbsPer100g: 5,
                fiberPer100g: 0,
                proteinPer100g: 8,
                fatPer100g: 3,
                nutritionConfidence: .8,
              ),
            );
        final useCase = FindMatchingIngredientForScanResultUseCase(
          db: db,
          findIngredientByBarcode: FindIngredientByBarcodeUseCase(db: db),
          matcher: const IngredientMatcher(),
        );
        final match = await useCase.callReadOnly(
          const IngredientScanResult(
            status: IngredientScanStatus.recognized,
            name: 'Yogurt',
            brand: 'Brand',
            barcode: '5901234123457',
            nutritionPer100g: NutritionPer100g(
              carbs: 5,
              fiber: 0,
              fat: 3,
              protein: 8,
            ),
            portions: [],
            retakeRequest: null,
          ),
        );
        expect(match?.id, existingCode == null ? id : null);
        expect(
          (await db.ingredientDao.getIngredientById(id)).barcode,
          existingCode,
        );
      },
    );
  }
}
