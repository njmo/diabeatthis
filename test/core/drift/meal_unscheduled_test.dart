import 'dart:io';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late DatabaseImpl db;
  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'untimed meal is visible today but is not a timed reminder candidate',
    () async {
      final now = DateTime(2026, 11, 19, 12);
      await db.customStatement(
        'INSERT INTO meal (name, planned_at, planned_day) VALUES (?, NULL, ?)',
        ['Lunch', '2026-11-19'],
      );
      final visible = await db.mealDao
          .getAllPlannedMealForToday(asOf: now)
          .first;
      expect(visible.map((m) => m.name), contains('Lunch'));
      expect(
        await withClock(Clock.fixed(now), () => db.mealDao.getNearestMeal()),
        isNull,
      );
    },
  );

  test(
    'first activation gives an untimed meal a time without altering timed meals',
    () async {
      final now = DateTime(2026, 11, 19, 12);
      await db.customStatement(
        'INSERT INTO meal (name, planned_at, planned_day) VALUES (?, NULL, ?)',
        ['Lunch', '2026-11-19'],
      );
      final untimed =
          (await db
                  .customSelect(
                    'SELECT id FROM meal WHERE name = ?',
                    variables: [Variable.withString('Lunch')],
                  )
                  .getSingle())
              .read<int>('id');
      final scheduled = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Dinner',
              plannedAt: Value(
                now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
              ),
            ),
          );
      await withClock(
        Clock.fixed(now),
        () => db.mealDao.tryUpdateMealStatus(untimed, 'bolused-waiting'),
      );
      await withClock(
        Clock.fixed(now),
        () => db.mealDao.tryUpdateMealStatus(scheduled, 'eating'),
      );
      expect(
        (await db.mealDao.getMealById(scheduled))!.plannedAt,
        now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
      );
      expect(
        (await db.mealDao.getMealById(untimed))!.plannedAt,
        now.millisecondsSinceEpoch,
      );
    },
  );

  test('v51 upgrade keeps meal history and captures a new plan day', () async {
    final dir = await Directory.systemTemp.createTemp('meal-plan-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/meal.db');
    final original = DatabaseImpl(NativeDatabase(file));
    await original.customStatement(
      "INSERT INTO meal(id, name, planned_at) VALUES (1, 'Existing', 1234)",
    );
    await original.mealDao.updateMealStatus(1, 'eating');
    await original.close();
    final legacy = sqlite3.open(file.path);
    for (final event in ['insert', 'update', 'delete']) {
      legacy.execute('DROP TRIGGER family_sync_meal_$event');
    }
    legacy.execute('ALTER TABLE meal DROP COLUMN planned_day');
    legacy.execute('''
      CREATE TRIGGER family_sync_meal_insert AFTER INSERT ON meal BEGIN
        INSERT INTO family_sync_outbox(kind, entity_id, revision, payload)
        VALUES('meals', CAST(NEW.id AS TEXT), 1, json_object('planned_at', NEW.planned_at));
      END
    ''');
    legacy.execute('PRAGMA user_version = 51');
    legacy.dispose();
    final upgraded = DatabaseImpl(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect((await upgraded.mealDao.getMealById(1))!.plannedAt, 1234);
    expect(await upgraded.select(upgraded.mealStatusHistory).get(), isNotEmpty);
    await upgraded.customStatement(
      "INSERT INTO meal(id, name, planned_day) VALUES (2, 'Lunch', '2026-11-19')",
    );
    final outbox = await upgraded
        .customSelect(
          "SELECT json_extract(payload, '\$.planned_day') AS day FROM family_sync_outbox WHERE kind = 'meals' AND entity_id = '2'",
        )
        .getSingle();
    expect(outbox.read<String>('day'), '2026-11-19');
    expect(
      await upgraded.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
  });
}
