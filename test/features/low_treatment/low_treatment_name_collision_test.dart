import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/persistence/insert_meal_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  final at = DateTime(2026, 10, 28, 7, 50);
  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'historical low treatments at the same time preserve both entries',
    () async {
      final existing = await db.mealDao.createLowTreatmentEntry(
        name: 'Rescue',
        eatenAt: at,
        notes: 'Original',
      );
      final draft = MealDraft(
        name: 'Rescue',
        mealIngredients: [],
        plannedAt: at,
        purpose: MealPurpose.lowTreatment,
        status: 'confirmed',
      );
      final second = await insertMealDraft(db, draft);
      final third = await insertMealDraft(db, draft);
      expect(second.id, isNot(existing.id));
      expect(second.name, '');
      expect(third.name, '');
      expect(second.plannedAt, at);
      final unchanged = (await db.mealDao.getMealById(existing.id))!;
      expect(unchanged.name, '');
      expect(unchanged.notes, 'Original');
      expect(unchanged.plannedAt, at.millisecondsSinceEpoch);
    },
  );

  test('direct low treatment creation shares collision handling', () async {
    final first = await db.mealDao.createLowTreatmentEntry(
      name: 'Rescue',
      eatenAt: at,
    );
    final second = await db.mealDao.createLowTreatmentEntry(
      name: 'Rescue',
      eatenAt: at,
    );
    expect(second.id, isNot(first.id));
    expect(second.name, '');
    expect(second.plannedAt, first.plannedAt);
    final anotherTime = await db.mealDao.createLowTreatmentEntry(
      name: 'Rescue',
      eatenAt: at.add(const Duration(minutes: 1)),
    );
    expect(anotherTime.name, '');
  });

  test('collision with an ordinary meal does not overwrite it', () async {
    await insertMealDraft(
      db,
      MealDraft(
        name: 'Rescue',
        mealIngredients: [],
        plannedAt: at,
        status: 'eaten',
      ),
    );
    final low = await db.mealDao.createLowTreatmentEntry(
      name: 'Rescue',
      eatenAt: at,
    );
    expect(low.name, '');
    expect((await db.select(db.meal).get()).length, 2);
  });
}
