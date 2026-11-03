import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class Version37MealConfirmationDatabase extends DatabaseImpl {
  Version37MealConfirmationDatabase(super.executor);

  @override
  int get schemaVersion => 37;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'ALTER TABLE meal DROP COLUMN consumption_confirmed_ended_at',
      );
    },
  );
}

void main() {
  test(
    'version 37 retains meals, consumption and bolus links without inferring confirmation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'meal-confirmation-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = Version37MealConfirmationDatabase(NativeDatabase(file));
      await old.customStatement(
        "INSERT INTO meal (id, name, planned_at, status, notes) VALUES (1, 'Lunch', 1000, 'waiting-for-bolus', 'Keep this note')",
      );
      await old.customStatement(
        "INSERT INTO meal_status_history (meal_id, status, created_at) VALUES (1, 'waiting-for-bolus', 2000)",
      );
      await old.customStatement(
        "INSERT INTO meal_wizard_link (meal_id, remote_wizard_id, remote_source, relation_type) VALUES (1, 'wizard-id', 'https://example.com', 'initial')",
      );
      await old.customStatement('''INSERT INTO meal_snapshot
      (meal_id, snapshot_type, total_grams, total_carbs_g, total_fiber_g, total_net_carbs_g, total_fat_g, total_protein_g, total_calories_kcal, ingredients_count)
      VALUES (1, 'consumed', 50, 10, 0, 10, 0, 1, 44, 1)''');
      await old.close();

      final db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      final meal = await db.mealDao.getMealById(1);
      expect(meal?.status, 'waiting-for-bolus');
      expect(meal?.notes, 'Keep this note');
      expect(meal?.plannedAt, 1000);
      expect(meal?.consumptionConfirmedEndedAt, isNull);
      expect(
        (await db.select(db.mealStatusHistory).get()).single.createdAt,
        2000,
      );
      expect((await db.select(db.mealSnapshot).get()).single.totalGrams, 50);
      expect(
        (await db.select(db.mealWizardLink).get()).single.remoteWizardId,
        'wizard-id',
      );
      expect(db.schemaVersion, greaterThan(41));
    },
  );
}
