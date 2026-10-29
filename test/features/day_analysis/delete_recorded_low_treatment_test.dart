import 'package:diabeatthis/core/domain/model/treat.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_review_repository.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/recorded_low_treatment_repository.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/build_low_treatment_review_use_case.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/delete_recorded_low_treatment_use_case.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'undo retains visible consumption and deletion cleans all its links',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final time = DateTime(2026, 10, 28, 12);
      final meal = await db.mealDao.createLowTreatmentEntry(
        name: 'Glucose',
        eatenAt: time,
      );
      final event = domain.Treat(
        externalId: 'carbs',
        createdAt: time,
        carbs: 12,
      );
      final review = LowTreatmentReviewRepository(db);
      final recorded = RecordedLowTreatmentRepository(db);
      await db.lowTreatmentContextDao.upsertContextForMeal(
        LowTreatmentContextCompanion.insert(
          mealId: Value(meal.id),
          source: 'manual',
        ),
      );
      await db
          .into(db.lowTreatmentHandoff)
          .insert(
            LowTreatmentHandoffCompanion.insert(
              mealId: Value(meal.id),
              savedAt: time.millisecondsSinceEpoch,
              expectedCarbs: 12,
            ),
          );
      await review.save(event, mealId: meal.id);
      await review.reset(time);
      final entries = const BuildLowTreatmentReviewUseCase()(
        events: [event],
        recorded: await recorded.fetchBetween(time, time),
        decisions: await review.fetch(time, time),
      );
      expect(entries.where((e) => e.recorded?.mealId == meal.id), hasLength(1));
      expect(entries.where((e) => e.isPending), hasLength(1));
      await review.save(event, mealId: meal.id);
      await DeleteRecordedLowTreatmentUseCase(db)(meal.id);
      expect(await recorded.fetchBetween(time, time), isEmpty);
      expect(await review.fetch(time, time), isEmpty);
      expect(await db.select(db.lowTreatmentContext).get(), isEmpty);
      expect(await db.select(db.lowTreatmentHandoff).get(), isEmpty);
      expect(
        const BuildLowTreatmentReviewUseCase()(
          events: [event],
          recorded: [],
          decisions: [],
        ).single.event,
        event,
      );
    },
  );

  test('deletion rejects a regular meal', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Breakfast',
            plannedAt: DateTime(2026, 10, 28).millisecondsSinceEpoch,
          ),
        );
    await expectLater(
      DeleteRecordedLowTreatmentUseCase(db)(id),
      throwsStateError,
    );
    expect(await db.mealDao.getMealById(id), isNotNull);
  });
}
