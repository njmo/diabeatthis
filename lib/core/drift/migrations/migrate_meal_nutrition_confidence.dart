import 'package:drift/drift.dart';

import '../database_impl.dart';

Future<void> migrateMealNutritionConfidence(DatabaseImpl db) async {
  final columns = await db
      .customSelect('PRAGMA table_info(meal_ingredients)')
      .get();
  if (!columns.any(
    (column) => column.read<String>('name') == 'nutrition_confidence_override',
  )) {
    await db.customStatement(
      'ALTER TABLE meal_ingredients ADD COLUMN nutrition_confidence_override REAL '
      'CHECK (nutrition_confidence_override IS NULL OR '
      '(nutrition_confidence_override >= 0 AND nutrition_confidence_override <= 1))',
    );
  }
  await db.customStatement(
    'DROP TRIGGER IF EXISTS meal_ingredients_summary_set_updated_at',
  );
  await Migrator(db).createTrigger(db.mealIngredientsSummarySetUpdatedAt);
}
