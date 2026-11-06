import 'dart:convert';

import 'package:diabeatthis/common/family_sync/apply_family_plan_use_case.dart';
import 'package:diabeatthis/common/family_sync/family_plan_scope.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:diabeatthis/core/drift/family_sync/load_family_plan_rows.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Map<String, dynamic>> localPlan(
  DatabaseImpl db,
  String type, {
  int? targetId,
  Map<String, dynamic>? values,
}) async {
  final source = await FamilyMirrorOutbox(db).bindOwner('child');
  await db.customStatement('UPDATE family_sync_identity SET enabled=1');
  final plan = <String, dynamic>{
    'id': 'a' * 32,
    'sourceId': source,
    'type': type,
    'targetId': targetId,
    'values':
        values ??
        {
          'name': 'Lunch',
          'category': 'lunch',
          'notes': '',
          'plannedAt': DateTime.now()
              .add(const Duration(hours: 2))
              .millisecondsSinceEpoch,
          'ingredients': [
            {
              'ingredientId': 1,
              'catalogId': null,
              'catalogRevision': null,
              'grams': 100.0,
            },
          ],
        },
    'authorActive': true,
    'claimToken': 'b' * 32,
    'claimUntil': DateTime.now()
        .add(const Duration(seconds: 30))
        .millisecondsSinceEpoch,
  };
  plan['expected'] = familyPlanVersions(
    familyPlanScope(await loadFamilyPlanRows(db, plan), plan),
  );
  return plan;
}

Future<void> seedPlanIngredient(DatabaseImpl db) => db.customStatement(
  "INSERT INTO ingredient(name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,nutrition_confidence) VALUES('Bread',40,2,3,8,1)",
);
void main() {
  test(
    'meal application and journal are atomic and replay does not duplicate',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPlanIngredient(db);
      final plan = await localPlan(db, 'createMeal');
      final apply = ApplyFamilyPlanUseCase(db);
      await apply('child', plan);
      await apply('child', plan);
      expect((await db.select(db.meal).get()), hasLength(1));
      final meal = (await db.select(db.meal).getSingle());
      expect(meal.status, 'planned');
      expect((await db.select(db.mealIngredients).getSingle()).amount, 100);
      final journal = await db
          .customSelect('SELECT * FROM family_plan_journal')
          .getSingle();
      expect(journal.read<String>('outcome'), 'applied');
      expect(
        jsonDecode(journal.read<String>('required_revisions')),
        isNotEmpty,
      );
      expect(journal.read<int>('acknowledged'), 0);
    },
  );
  test(
    'offline ingredient edits reject parent proposal without overwriting child',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPlanIngredient(db);
      final plan = await localPlan(db, 'createMeal');
      await db.customStatement(
        'UPDATE ingredient SET carbs_per_100g=55 WHERE id=1',
      );
      await ApplyFamilyPlanUseCase(db)('child', plan);
      expect(await db.select(db.meal).get(), isEmpty);
      expect((await db.select(db.ingredient).getSingle()).carbsPer100g, 55);
      expect(
        (await db
                .customSelect('SELECT reason FROM family_plan_journal')
                .getSingle())
            .read<String>('reason'),
        'conflict',
      );
    },
  );
  test(
    'new child meal component is part of aggregate conflict detection',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPlanIngredient(db);
      final create = await localPlan(db, 'createMeal');
      await ApplyFamilyPlanUseCase(db)('child', create);
      final update = await localPlan(db, 'updateMeal', targetId: 1);
      update['id'] = 'c' * 32;
      await db.customStatement(
        'INSERT INTO meal_ingredients(meal_id,ingredient_id,amount,quantity_confidence) VALUES(1,1,20,1)',
      );
      await ApplyFamilyPlanUseCase(db)('child', update);
      expect(await db.select(db.mealIngredients).get(), hasLength(2));
      expect(
        (await db
                .customSelect(
                  "SELECT reason FROM family_plan_journal WHERE reason IS NOT NULL",
                )
                .getSingle())
            .read<String>('reason'),
        'conflict',
      );
    },
  );
  test(
    'expired claim or account switch rolls back without acknowledgement',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPlanIngredient(db);
      final plan = await localPlan(db, 'createMeal');
      plan['claimUntil'] = 0;
      await expectLater(
        ApplyFamilyPlanUseCase(db)('child', plan),
        throwsStateError,
      );
      plan['claimUntil'] = DateTime.now()
          .add(const Duration(seconds: 30))
          .millisecondsSinceEpoch;
      var calls = 0;
      await expectLater(
        ApplyFamilyPlanUseCase(db)(
          'child',
          plan,
          stillAuthorized: () => ++calls == 1,
        ),
        throwsStateError,
      );
      expect(await db.select(db.meal).get(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM family_plan_journal').get(),
        isEmpty,
      );
    },
  );
  test(
    'activity one-off, daily confirmation and move reuse local scheduling',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO activity(name,percentage_pre,percentage_post,duration_minutes) VALUES('Walk',10,10,30)",
      );
      final start = DateTime.now()
          .add(const Duration(hours: 3))
          .millisecondsSinceEpoch;
      final plan = await localPlan(
        db,
        'planActivity',
        values: {'activityId': 1, 'startedAt': start, 'durationMinutes': 30},
      );
      await ApplyFamilyPlanUseCase(db)('child', plan);
      final first = await db.select(db.activityOccurrence).getSingle();
      expect(first.status, 'planned');
      final move = await localPlan(
        db,
        'moveActivity',
        targetId: first.id,
        values: {'startedAt': start + 3600000},
      );
      move['id'] = 'c' * 32;
      await ApplyFamilyPlanUseCase(db)('child', move);
      expect(
        (await db.select(db.activityLog).getSingle()).startedAt,
        start + 3600000,
      );
      expect(
        (await db
                .customSelect(
                  "SELECT cancel_occurrence_id FROM family_plan_journal WHERE outcome='applied' AND cancel_occurrence_id IS NOT NULL",
                )
                .getSingle())
            .read<int>('cancel_occurrence_id'),
        first.id,
      );
      await db.customStatement(
        "INSERT INTO activity_occurrence(activity_id,started_at,action_at,confirmation_mode) VALUES(1,?,?, 'before')",
        [start + 7200000, start],
      );
      final pending = (await db.select(db.activityOccurrence).get()).last;
      final confirm = await localPlan(
        db,
        'confirmActivity',
        targetId: pending.id,
        values: {},
      );
      confirm['id'] = 'd' * 32;
      await ApplyFamilyPlanUseCase(db)('child', confirm);
      expect((await db.select(db.activityLog).get()), hasLength(2));
    },
  );
  test(
    'catalog ingredient is mirrored only on child and becomes a meal dependency',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final revision = 'e' * 64;
      final catalog = CatalogIngredient(
        identity: const IngredientIdentity(
          source: IngredientSource.firebase,
          sourceId: 'usda_1',
        ),
        name: 'Apple',
        englishName: 'Apple',
        revision: revision,
        carbsPer100g: 12,
        fiberPer100g: 2,
        fatPer100g: 0,
        proteinPer100g: 0,
        carbsLabelMode: CarbsLabelMode.eu,
      );
      final plan = await localPlan(
        db,
        'createMeal',
        values: {
          'name': 'Snack',
          'category': 'snack',
          'notes': '',
          'plannedAt': DateTime.now()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          'ingredients': [
            {
              'ingredientId': null,
              'catalogId': 'usda_1',
              'catalogRevision': revision,
              'grams': 150.0,
            },
          ],
        },
      );
      await ApplyFamilyPlanUseCase(db)(
        'child',
        plan,
        catalogIngredients: {'usda_1': catalog},
      );
      expect((await db.select(db.ingredient).getSingle()).name, 'Apple');
      expect((await db.select(db.mealIngredients).getSingle()).amount, 150);
    },
  );
}
