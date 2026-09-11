import 'package:drift/drift.dart';

import '../../../../core/domain/model/treat.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../../domain/models/low_treatment_review_decision.dart';

class LowTreatmentReviewRepository {
  final DatabaseImpl db;
  const LowTreatmentReviewRepository(this.db);

  Future<List<LowTreatmentReviewDecision>> fetch(
    DateTime start,
    DateTime end,
  ) async {
    final rows =
        await (db.select(db.lowTreatmentReview)..where(
              (row) => row.occurredAt.isBetweenValues(
                start.millisecondsSinceEpoch,
                end.millisecondsSinceEpoch,
              ),
            ))
            .get();
    return rows
        .map(
          (row) => LowTreatmentReviewDecision(
            occurredAt: DateTime.fromMillisecondsSinceEpoch(row.occurredAt),
            externalId: row.externalId,
            mealId: row.mealId,
            dismissed: row.dismissed,
          ),
        )
        .toList();
  }

  Future<void> save(
    domain.Treat event, {
    int? mealId,
    bool dismissed = false,
  }) => db.transaction(() async {
    if (!event.isValid || event.carbs <= 0) {
      throw ArgumentError('Invalid carbohydrate entry');
    }
    final previous =
        await (db.select(db.lowTreatmentReview)..where(
              (row) =>
                  row.occurredAt.equals(event.createdAt.millisecondsSinceEpoch),
            ))
            .getSingleOrNull();
    if (previous?.externalId != null &&
        event.externalId != null &&
        previous!.externalId != event.externalId) {
      throw StateError('Conflicting carbohydrate identities');
    }
    if (mealId != null) {
      final meal = await db.mealDao.getMealById(mealId);
      if (meal == null ||
          meal.purpose != 'lowTreatment' ||
          meal.status != 'confirmed') {
        throw StateError('Recorded low treatment required');
      }
      final date = DateTime.fromMillisecondsSinceEpoch(meal.plannedAt);
      final eventDate = event.createdAt.toLocal();
      if (DateTime(date.year, date.month, date.day) !=
          DateTime(eventDate.year, eventDate.month, eventDate.day)) {
        throw ArgumentError('Low treatment must belong to the same day');
      }
    }
    await db
        .into(db.lowTreatmentReview)
        .insertOnConflictUpdate(
          LowTreatmentReviewCompanion.insert(
            occurredAt: Value(event.createdAt.millisecondsSinceEpoch),
            externalId: Value(event.externalId ?? previous?.externalId),
            mealId: Value(mealId),
            dismissed: Value(dismissed),
          ),
        );
  });

  Future<void> reset(DateTime occurredAt) =>
      (db.delete(db.lowTreatmentReview)..where(
            (row) => row.occurredAt.equals(occurredAt.millisecondsSinceEpoch),
          ))
          .go();
}
