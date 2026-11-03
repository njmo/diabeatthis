import 'package:diabeatthis/core/drift/database_impl.dart';

Future<DateTime> seedRecordedPortionMeal(DatabaseImpl db) async {
  final at = DateTime.now().subtract(const Duration(hours: 2));
  final stamp = at.millisecondsSinceEpoch;
  await db.customStatement(
    "INSERT INTO ingredient(id,name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,nutrition_confidence,created_at,updated_at) VALUES(1,'Bread',50,0,0,0,1,$stamp,$stamp)",
  );
  await db.customStatement(
    "INSERT INTO portion(id,name,unit_hint) VALUES(999,'Slice','piece')",
  );
  await db.customStatement(
    'INSERT INTO ingredient_portions(ingredient_id,portion_id,grams_per_portion) VALUES(1,999,30)',
  );
  await db.customStatement(
    "INSERT INTO meal(id,name,planned_at,status,created_at,updated_at) VALUES(1,'Recorded bread',$stamp,'summarized',$stamp,$stamp)",
  );
  await db.customStatement(
    "INSERT INTO meal_snapshot(meal_id,snapshot_type,total_grams,total_carbs_g,total_fiber_g,total_net_carbs_g,total_fat_g,total_protein_g,total_calories_kcal,created_at,updated_at,calculated_at) VALUES(1,'consumed',70,35,0,35,0,0,140,$stamp,$stamp,$stamp)",
  );
  await db.customStatement(
    'INSERT INTO meal_ingredients(meal_id,ingredient_id,portion_id,amount,consumed_amount,quantity_confidence,created_at,updated_at) VALUES(1,1,999,2,2,1,$stamp,$stamp)',
  );
  await db.customStatement(
    'INSERT INTO meal_ingredients(meal_id,ingredient_id,amount,consumed_amount,quantity_confidence,created_at,updated_at) VALUES(1,1,10,10,1,$stamp,$stamp)',
  );
  return at;
}
