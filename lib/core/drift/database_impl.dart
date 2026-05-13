import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'dao/activity_dao.dart';
import 'dao/ingredient_dao.dart';
import 'dao/meal_advisor_result_dao.dart';
import 'dao/meal_dao.dart';
import 'dao/meal_ingredients_dao.dart';
import 'dao/meal_template_dao.dart';
import 'dao/meal_template_ingredients_dao.dart';
import 'dao/portion_dao.dart';
import 'database.dart';

part 'database_impl.g.dart';

@DriftDatabase(
  include: {'schemas/schema.drift'},
  daos: [
    IngredientDao,
    PortionDao,
    MealDao,
    MealAdvisorResultDao,
    ActivityDao,
    MealTemplateDao,
    MealIngredientsDao,
    MealTemplateIngredientsDao,
  ],
)
class DatabaseImpl extends _$DatabaseImpl implements Database {
  DatabaseImpl([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'my_database',
      native: const DriftNativeOptions(
        shareAcrossIsolates: true,
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _addActivityDurationColumnIfMissing();
      }
      if (from < 3) {
        await _addMealAdvisorExtendedCarbsColumnsIfMissing();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _addActivityDurationColumnIfMissing() async {
    final columns = await customSelect('PRAGMA table_info(activity)').get();
    final hasDurationColumn = columns.any(
      (row) => row.data['name'] == 'duration_minutes',
    );

    if (hasDurationColumn) return;

    await customStatement('''
      ALTER TABLE activity
      ADD COLUMN duration_minutes INTEGER
      CHECK (duration_minutes IS NULL OR duration_minutes > 0)
    ''');
  }

  Future<void> _addMealAdvisorExtendedCarbsColumnsIfMissing() async {
    await _addMealAdvisorResultColumnIfMissing(
      name: 'extended_carbs_grams',
      definition: 'extended_carbs_grams INTEGER NOT NULL DEFAULT 0',
    );
    await _addMealAdvisorResultColumnIfMissing(
      name: 'extended_carbs_delivery_mode',
      definition: 'extended_carbs_delivery_mode TEXT',
    );
    await _addMealAdvisorResultColumnIfMissing(
      name: 'extended_carbs_delay_minutes',
      definition: 'extended_carbs_delay_minutes INTEGER',
    );
    await _addMealAdvisorResultColumnIfMissing(
      name: 'extended_carbs_duration_minutes',
      definition: 'extended_carbs_duration_minutes INTEGER',
    );
  }

  Future<void> _addMealAdvisorResultColumnIfMissing({
    required String name,
    required String definition,
  }) async {
    final columns = await customSelect(
      'PRAGMA table_info(meal_advisor_result)',
    ).get();
    final hasColumn = columns.any((row) => row.data['name'] == name);

    if (hasColumn) return;

    await customStatement('''
      ALTER TABLE meal_advisor_result
      ADD COLUMN $definition
    ''');
  }

  Future<void> deleteEverything() async {
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        for (final table in allTables) {
          await delete(table).go();
        }
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }
}
