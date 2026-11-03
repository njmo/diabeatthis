import 'dart:convert';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/settings/data/database_backup_scope.dart';
import 'package:diabeatthis/features/settings/data/database_backup_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final legacy in [false, true]) {
    test(
      'backup restore preserves recorded conversion provenance; legacy=$legacy',
      () async {
        final source = DatabaseImpl(NativeDatabase.memory());
        final target = DatabaseImpl(NativeDatabase.memory());
        addTearDown(() async {
          await source.close();
          await target.close();
        });
        await source.customStatement(
          "INSERT INTO ingredient (id,name,carbs_per_100g,fiber_per_100g,fat_per_100g,protein_per_100g,nutrition_confidence) VALUES (1,'Bread',50,0,0,0,1)",
        );
        await source.customStatement(
          "INSERT INTO portion (id,name,unit_hint) VALUES (999,'Slice','piece')",
        );
        await source.customStatement(
          'INSERT INTO ingredient_portions (ingredient_id,portion_id,grams_per_portion) VALUES (1,999,30)',
        );
        await source.customStatement(
          "INSERT INTO meal (id,name,planned_at,status) VALUES (1,'Two slices',1000,'summarized')",
        );
        await source.customStatement(
          'INSERT INTO meal_ingredients (meal_id,ingredient_id,portion_id,amount,quantity_confidence,created_at,updated_at) VALUES (1,1,999,2,1,1000,1000)',
        );
        final original =
            (await source.select(source.mealIngredients).get()).single;
        expect(original.gramsPerPortionUsed, 30);
        expect(
          original.updatedAt,
          1000,
          reason: 'Capturing the initial conversion is not an edit.',
        );
        await source.portionDao.updateIngredientPortionAmount(
          ingredientId: 1,
          portionId: 999,
          gramsPerPortion: 40,
        );
        final payload =
            jsonDecode(
                  jsonEncode(
                    await DatabaseBackupService(
                      source,
                    ).exportToJson(DatabaseBackupScope.full),
                  ),
                )
                as Map<String, Object?>;
        if (legacy) {
          for (final row
              in (payload['tables'] as Map)['meal_ingredients'] as List) {
            (row as Map).remove('grams_per_portion_used');
          }
        }
        await DatabaseBackupService(target).importFromJson(payload);
        final restored =
            (await target.select(target.mealIngredients).get()).single;
        expect(restored.gramsPerPortionUsed, legacy ? isNull : 30);
        expect(restored.updatedAt, 1000);
        final invalid = jsonDecode(jsonEncode(payload)) as Map<String, Object?>;
        final invalidRows =
            (invalid['tables'] as Map)['meal_ingredients'] as List;
        (invalidRows.single as Map)['quantity_confidence'] = 2;
        await expectLater(
          DatabaseBackupService(target).importFromJson(invalid),
          throwsA(anything),
        );
        final afterFailedRestore =
            (await target.select(target.mealIngredients).get()).single;
        expect(
          afterFailedRestore.gramsPerPortionUsed,
          restored.gramsPerPortionUsed,
        );
        expect(afterFailedRestore.updatedAt, restored.updatedAt);
        await target.customStatement(
          'INSERT INTO meal_ingredients (meal_id,ingredient_id,portion_id,amount,quantity_confidence) VALUES (1,1,999,1,1)',
        );
        final live = (await target.select(target.mealIngredients).get()).last;
        expect(
          live.gramsPerPortionUsed,
          40,
          reason: 'Live capture must be restored after backup import.',
        );
      },
    );
  }
}
