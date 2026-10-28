import 'package:drift/drift.dart';

import '../database_impl.dart';

Future<void> migrateTypedLowTreatments(
  DatabaseImpl db,
  Migrator migrator,
) async {
  await migrator.alterTable(
    // ignore: experimental_member_use
    TableMigration(
      db.meal,
      columnTransformer: {
        db.meal.name: const CustomExpression<String>(
          "CASE WHEN purpose = 'lowTreatment' THEN '' ELSE name END",
        ),
        db.meal.isSynced: const CustomExpression<bool>(
          "CASE WHEN purpose = 'lowTreatment' THEN 0 ELSE is_synced END",
        ),
      },
    ),
  );
  await db.customStatement(
    "CREATE UNIQUE INDEX IF NOT EXISTS uq_named_meal_time ON meal(name, planned_at) WHERE purpose = 'meal'",
  );
}
