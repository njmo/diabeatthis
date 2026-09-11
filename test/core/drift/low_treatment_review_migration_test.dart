import 'dart:io';

import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide Treat;
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_review_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'v26 upgrade preserves meals and persists new review decisions across reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('low-review-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/test.sqlite');
      var db = DatabaseImpl(NativeDatabase(file));
      final mealId = await db
          .into(db.meal)
          .insert(MealCompanion.insert(name: 'Existing', plannedAt: 1000));
      await db.customStatement('DROP TABLE low_treatment_review');
      await db.customStatement('PRAGMA user_version = 26');
      await db.close();
      db = DatabaseImpl(NativeDatabase(file));
      final time = DateTime(2026, 9, 10);
      expect((await db.mealDao.getMealById(mealId))!.name, 'Existing');
      await LowTreatmentReviewRepository(db).save(
        Treat(externalId: 'id', createdAt: time, carbs: 12),
        dismissed: true,
      );
      await db.close();
      db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      expect(
        (await LowTreatmentReviewRepository(
          db,
        ).fetch(time, time)).single.dismissed,
        isTrue,
      );
    },
  );
}
