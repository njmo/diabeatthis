import 'package:drift/drift.dart';

import '../../../../core/domain/model/treat.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../../domain/models/low_treatment_handoff_match.dart';
import '../../domain/models/low_treatment_handoff_pending.dart';
import '../../domain/repositories/low_treatment_handoff_gateway.dart';
import '../../domain/use_cases/match_low_treatment_handoffs_use_case.dart';

class LowTreatmentHandoffRepository implements LowTreatmentHandoffGateway {
  final DatabaseImpl db;
  const LowTreatmentHandoffRepository(this.db);

  @override
  Future<void> register({
    required int mealId,
    required DateTime savedAt,
    required double expectedCarbs,
    required DateTime? suggestionAt,
  }) => db.transaction(() async {
    final existing = await _byMealId(mealId);
    if (existing == null) {
      await db
          .into(db.lowTreatmentHandoff)
          .insert(
            LowTreatmentHandoffCompanion.insert(
              mealId: Value(mealId),
              savedAt: savedAt.millisecondsSinceEpoch,
              expectedCarbs: expectedCarbs,
              suggestionAt: Value(suggestionAt?.millisecondsSinceEpoch),
            ),
          );
      return;
    }
    if (existing.savedAt != savedAt ||
        existing.expectedCarbs != expectedCarbs ||
        existing.suggestionAt != suggestionAt) {
      throw StateError('Conflicting low treatment handoff');
    }
  });

  @override
  Future<bool> hasPending() async =>
      await (db.select(db.lowTreatmentHandoff)..limit(1)).getSingleOrNull() !=
      null;

  @override
  Future<List<LowTreatmentHandoffPending>> loadPending() async {
    final rows = await db.select(db.lowTreatmentHandoff).get();
    return rows.map(_mapPending).toList(growable: false);
  }

  @override
  Future<List<LowTreatmentHandoffMatch>> reconcile(
    List<domain.Treat> treatments,
    DateTime now,
  ) => db.transaction(() async {
    final pending = await loadPending();
    if (pending.isEmpty) return const [];

    final reviews = await db.select(db.lowTreatmentReview).get();
    final reviewByTime = {
      for (final review in reviews) review.occurredAt: review,
    };
    final reviewedMealIds = reviews
        .map((review) => review.mealId)
        .whereType<int>()
        .toSet();
    final matches = <LowTreatmentHandoffMatch>[];
    final unresolved = <LowTreatmentHandoffPending>[];

    for (final item in pending) {
      final matchedAt = item.matchedTreatAt;
      if (matchedAt == null) {
        if (!reviewedMealIds.contains(item.mealId)) unresolved.add(item);
        continue;
      }
      final review = reviewByTime[matchedAt.millisecondsSinceEpoch];
      if (review?.mealId == item.mealId && !review!.dismissed) {
        matches.add(_match(item));
      } else {
        await _delete(item.mealId);
      }
    }

    final recordedAtByMeal = <int, DateTime>{};
    for (final item in unresolved) {
      final meal = await db.mealDao.getMealById(item.mealId);
      if (meal == null ||
          meal.purpose != 'lowTreatment' ||
          meal.status != 'confirmed') {
        await _delete(item.mealId);
        continue;
      }
      recordedAtByMeal[item.mealId] = DateTime.fromMillisecondsSinceEpoch(
        meal.plannedAt,
      );
    }
    final selected = const MatchLowTreatmentHandoffsUseCase()(
      pending: unresolved,
      recordedAtByMeal: recordedAtByMeal,
      treatments: treatments,
      occupiedMealIds: reviewedMealIds,
      occupiedTreatTimes: reviewByTime.keys.toSet(),
      now: now,
    );
    for (final item in unresolved) {
      final candidate = selected[item.mealId];
      if (candidate == null) continue;
      await db
          .into(db.lowTreatmentReview)
          .insert(
            LowTreatmentReviewCompanion.insert(
              occurredAt: Value(candidate.createdAt.millisecondsSinceEpoch),
              externalId: Value(candidate.externalId),
              mealId: Value(item.mealId),
              dismissed: const Value(false),
            ),
          );
      await (db.update(
        db.lowTreatmentHandoff,
      )..where((row) => row.mealId.equals(item.mealId))).write(
        LowTreatmentHandoffCompanion(
          matchedTreatAt: Value(candidate.createdAt.millisecondsSinceEpoch),
          matchedExternalId: Value(candidate.externalId),
        ),
      );
      matches.add(
        LowTreatmentHandoffMatch(
          mealId: item.mealId,
          suggestionAt: item.suggestionAt,
          treatAt: candidate.createdAt,
          treatExternalId: candidate.externalId,
        ),
      );
    }
    return matches;
  });

  @override
  Future<void> markCompleted(int mealId) => _delete(mealId);

  @override
  Future<void> discardSavedBefore(DateTime cutoff) =>
      (db.delete(db.lowTreatmentHandoff)..where(
            (row) =>
                row.savedAt.isSmallerThanValue(cutoff.millisecondsSinceEpoch),
          ))
          .go();

  Future<LowTreatmentHandoffPending?> _byMealId(int mealId) async {
    final row = await (db.select(
      db.lowTreatmentHandoff,
    )..where((row) => row.mealId.equals(mealId))).getSingleOrNull();
    return row == null ? null : _mapPending(row);
  }

  LowTreatmentHandoffPending _mapPending(LowTreatmentHandoffData row) =>
      LowTreatmentHandoffPending(
        mealId: row.mealId,
        savedAt: DateTime.fromMillisecondsSinceEpoch(row.savedAt),
        expectedCarbs: row.expectedCarbs,
        suggestionAt: row.suggestionAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.suggestionAt!),
        matchedTreatAt: row.matchedTreatAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.matchedTreatAt!),
        matchedExternalId: row.matchedExternalId,
      );

  LowTreatmentHandoffMatch _match(LowTreatmentHandoffPending item) =>
      LowTreatmentHandoffMatch(
        mealId: item.mealId,
        suggestionAt: item.suggestionAt,
        treatAt: item.matchedTreatAt!,
        treatExternalId: item.matchedExternalId,
      );

  Future<void> _delete(int mealId) => (db.delete(
    db.lowTreatmentHandoff,
  )..where((row) => row.mealId.equals(mealId))).go();
}
