import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class Version38MealAddOnDatabase extends DatabaseImpl {
  Version38MealAddOnDatabase(super.executor);

  @override
  int get schemaVersion => 38;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'ALTER TABLE meal DROP COLUMN add_on_bolus_context',
      );
    },
  );
}

void main() {
  test(
    'version 38 migration preserves existing meal facts without inferring an add-on bolus',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'meal-add-on-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = Version38MealAddOnDatabase(NativeDatabase(file));
      await old.customStatement(
        "INSERT INTO meal (id,name,planned_at,status,consumption_confirmed_ended_at) VALUES (1,'Lunch',1000,'waiting-for-bolus',2000)",
      );
      await old.customStatement(
        "INSERT INTO meal_status_history (meal_id,status,created_at) VALUES (1,'eating-then-bolus',1000),(1,'waiting-for-bolus',2000)",
      );
      await old.customStatement(
        "INSERT INTO meal_wizard_link (meal_id,remote_wizard_id,remote_source,relation_type) VALUES (1,'recorded','https://example.com','initial')",
      );
      await old.close();
      final db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      final meal = (await db.mealDao.getMealById(1))!;
      expect(db.schemaVersion, greaterThan(41));
      expect(meal.status, 'waiting-for-bolus');
      expect(meal.consumptionConfirmedEndedAt, 2000);
      expect(meal.addOnBolusContext, isNull);
      expect(await db.select(db.mealStatusHistory).get(), hasLength(2));
      expect(
        (await db.mealWizardLinkDao.forMeal(1)).single.remoteWizardId,
        'recorded',
      );
    },
  );
}
