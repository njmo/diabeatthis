import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' show MigrationStrategy, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class Version43LowTreatmentCarbsDatabase extends DatabaseImpl {
  Version43LowTreatmentCarbsDatabase(super.executor);
  @override
  int get schemaVersion => 43;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'ALTER TABLE low_treatment_context DROP COLUMN recorded_carbs',
      );
    },
  );
}

void main() {
  test(
    'version 43 preserves existing intake and adds authoritative returned carbs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'low-treatment-carbs-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/db.sqlite');
      final old = Version43LowTreatmentCarbsDatabase(NativeDatabase(file));
      final id = await old
          .into(old.meal)
          .insert(MealCompanion.insert(name: 'Existing', plannedAt: 1000));
      await old.customStatement(
        'INSERT INTO low_treatment_context (meal_id, source) VALUES (?, ?)',
        [id, 'manual'],
      );
      await old.close();
      final db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      expect(
        (await db.select(db.lowTreatmentContext).get()).single.recordedCarbs,
        isNull,
      );
      await (db.update(
        db.lowTreatmentContext,
      )).write(const LowTreatmentContextCompanion(recordedCarbs: Value(8)));
      expect(
        (await db.lowTreatmentContextDao.getContextForMeal(id))!.recordedCarbs,
        8,
      );
    },
  );
}
