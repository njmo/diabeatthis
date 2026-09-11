import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'version 25 links survive migration and can be explicitly dismissed',
    () async {
      final dir = await Directory.systemTemp.createTemp('wizard-dismissal-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/history.sqlite');
      var db = DatabaseImpl(NativeDatabase(file));
      final meal = await db
          .into(db.meal)
          .insert(MealCompanion.insert(name: 'Lunch', plannedAt: 1000));
      await MealWizardLinkRepository(db).link(
        mealId: meal,
        remoteWizardId: 'ns',
        remoteSource: 'https://example.com',
      );
      final id = (await MealWizardLinkRepository(db).forMeal(meal)).single.id;
      await db.customStatement(
        'ALTER TABLE meal_wizard_link DROP COLUMN dismissed',
      );
      await db.customStatement('PRAGMA user_version = 25');
      await db.close();
      db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      final links = MealWizardLinkRepository(db);
      final restored = (await links.forMeal(meal)).single;
      expect(restored.id, id);
      expect(restored.dismissed, isFalse);
      await links.unlink(id);
      expect(await links.forMeal(meal), isEmpty);
      expect(
        (await db.select(db.mealWizardLink).get()).single.dismissed,
        isTrue,
      );
    },
  );
}
