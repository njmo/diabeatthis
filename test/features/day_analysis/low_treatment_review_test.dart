import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_review_repository.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_review_decision.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/build_low_treatment_review_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final time = DateTime(2026, 9, 10, 12);
  final event = Treat(externalId: 'one', createdAt: time, carbs: 12);
  const build = BuildLowTreatmentReviewUseCase();
  test(
    'unlinked carbs remain a question, recorded consumption is retained',
    () {
      final low = RecordedLowTreatment(
        mealId: 1,
        eatenAt: time,
        netCarbsGrams: 12,
      );
      final entries = build(events: [event], recorded: [low], decisions: []);
      expect(entries, hasLength(2));
      expect(
        entries.where((entry) => entry.event != null).single.recorded,
        isNull,
      );
    },
  );
  test(
    'dismissed events stay dismissed and explicit links avoid duplicate local entries',
    () {
      final low = RecordedLowTreatment(
        mealId: 1,
        eatenAt: time,
        netCarbsGrams: 12,
      );
      final linked = build(
        events: [event, event],
        recorded: [low],
        decisions: [
          LowTreatmentReviewDecision(
            occurredAt: time,
            mealId: 1,
            dismissed: false,
          ),
        ],
      );
      expect(linked, hasLength(1));
      expect(linked.single.recorded, low);
      final rejected = build(
        events: [event],
        recorded: [],
        decisions: [
          LowTreatmentReviewDecision(occurredAt: time, dismissed: true),
        ],
      );
      expect(rejected.single.dismissed, isTrue);
    },
  );
  test('conflicting identities do not reuse a saved decision', () {
    final entries = build(
      events: [
        event,
        event.copyWith(externalId: 'other'),
      ],
      recorded: [],
      decisions: [
        LowTreatmentReviewDecision(
          occurredAt: time,
          externalId: 'one',
          dismissed: true,
        ),
      ],
    );
    expect(entries.single.ambiguous, isTrue);
    expect(entries.single.dismissed, isFalse);
  });
  test(
    'decisions persist without a local mirror, reset and reject wrong day or purpose',
    () async {
      final db = drift.DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LowTreatmentReviewRepository(db);
      final low = await db.mealDao.createLowTreatmentEntry(
        name: 'Low',
        eatenAt: time,
      );
      await repo.save(event, dismissed: true);
      expect((await repo.fetch(time, time)).single.dismissed, isTrue);
      await repo.reset(time);
      expect(await repo.fetch(time, time), isEmpty);
      await repo.save(event, mealId: low.id);
      expect((await repo.fetch(time, time)).single.mealId, low.id);
      await expectLater(
        repo.save(event.copyWith(externalId: 'conflict'), dismissed: true),
        throwsStateError,
      );
      final other = await db.mealDao.createLowTreatmentEntry(
        name: 'Other day',
        eatenAt: time.subtract(const Duration(days: 1)),
      );
      await expectLater(
        repo.save(event, mealId: other.id),
        throwsArgumentError,
      );
      final meal = await db
          .into(db.meal)
          .insert(
            drift.MealCompanion.insert(
              name: 'Meal',
              plannedAt: time.millisecondsSinceEpoch,
            ),
          );
      await expectLater(repo.save(event, mealId: meal), throwsStateError);
      expect((await repo.fetch(time, time)).single.mealId, low.id);
    },
  );
}
