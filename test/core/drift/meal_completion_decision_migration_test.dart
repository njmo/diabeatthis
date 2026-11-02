import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/migrations/migrate_meal_completion_decision.dart';
import 'package:drift/drift.dart' show MigrationStrategy, Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class Version39MealDecisionDatabase extends DatabaseImpl {
  Version39MealDecisionDatabase(super.executor);

  @override
  int get schemaVersion => 39;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('ALTER TABLE meal DROP COLUMN completion_decision');
    },
  );
}

void main() {
  test(
    'version 39 migration preserves facts without inferring a correction choice',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'meal-decision-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = Version39MealDecisionDatabase(NativeDatabase(file));
      await old.customStatement(
        "INSERT INTO meal (id,name,planned_at,status,notes,consumption_confirmed_ended_at) VALUES (1,'Lunch',1000,'summarized','Keep note',2000)",
      );
      await old.customStatement(
        "INSERT INTO meal_status_history (meal_id,status,created_at) VALUES (1,'eaten',2000)",
      );
      await old.customStatement(
        "INSERT INTO meal_wizard_link (meal_id,remote_wizard_id,remote_source,relation_type) VALUES (1,'wizard','https://example.com','initial')",
      );
      await old.close();

      final db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      final meal = (await db.mealDao.getMealById(1))!;
      expect(db.schemaVersion, 41);
      expect(meal.status, 'summarized');
      expect(meal.notes, 'Keep note');
      expect(meal.consumptionConfirmedEndedAt, 2000);
      expect(meal.completionDecision, isNull);
      expect(
        (await db.select(db.mealStatusHistory).get()).single.createdAt,
        2000,
      );
      expect(
        (await db.mealWizardLinkDao.forMeal(1)).single.remoteWizardId,
        'wizard',
      );
      await migrateMealCompletionDecision(db, Migrator(db));
      final columns = await db.customSelect('PRAGMA table_info(meal)').get();
      expect(
        columns.where(
          (row) => row.read<String>('name') == 'completion_decision',
        ),
        hasLength(1),
      );
    },
  );
}
