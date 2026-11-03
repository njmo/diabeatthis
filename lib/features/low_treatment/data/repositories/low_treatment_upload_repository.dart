import 'package:drift/drift.dart';

import '../../../../core/drift/database_impl.dart';

class LowTreatmentUploadRepository {
  const LowTreatmentUploadRepository(this.db);
  final DatabaseImpl db;

  Future<void> enqueue({
    required int mealId,
    required String identifier,
    required String sourceKey,
    required DateTime eatenAt,
    required double carbs,
  }) => db
      .into(db.lowTreatmentUpload)
      .insert(
        LowTreatmentUploadCompanion.insert(
          mealId: Value(mealId),
          identifier: identifier,
          sourceKey: sourceKey,
          eatenAt: eatenAt.millisecondsSinceEpoch,
          carbs: carbs,
        ),
      );

  Future<LowTreatmentUploadData?> find(int mealId) => (db.select(
    db.lowTreatmentUpload,
  )..where((t) => t.mealId.equals(mealId))).getSingleOrNull();

  Stream<LowTreatmentUploadData?> watch(int mealId) => (db.select(
    db.lowTreatmentUpload,
  )..where((t) => t.mealId.equals(mealId))).watchSingleOrNull();

  Future<List<LowTreatmentUploadData>> pending(DateTime now) =>
      (db.select(db.lowTreatmentUpload)..where(
            (t) =>
                t.state.isIn(['queued', 'verifying']) &
                t.nextAttemptAt.isSmallerOrEqualValue(
                  now.millisecondsSinceEpoch,
                ),
          ))
          .get();

  Future<void> update(
    int mealId,
    String state, {
    bool? attempted,
    DateTime? nextAttempt,
  }) async {
    await (db.update(
      db.lowTreatmentUpload,
    )..where((t) => t.mealId.equals(mealId))).write(
      LowTreatmentUploadCompanion(
        state: Value(state),
        attempted: attempted == null
            ? const Value.absent()
            : Value(attempted ? 1 : 0),
        nextAttemptAt: Value(nextAttempt?.millisecondsSinceEpoch ?? 0),
      ),
    );
  }

  Future<bool> hasMatchedTreatment(int mealId) async =>
      await (db.select(db.lowTreatmentReview)
            ..where((t) => t.mealId.equals(mealId) & t.dismissed.equals(false))
            ..limit(1))
          .getSingleOrNull() !=
      null;

  Future<void> link(
    LowTreatmentUploadData upload,
    String externalId,
  ) => db.transaction(() async {
    // V3 can omit the raw ObjectId used by v1 history. Never store its UUID as
    // a conflicting v1 identity; an absent ID retains the verified timestamp link.
    final historyId = RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(externalId)
        ? externalId
        : null;
    final meal = await db.mealDao.getMealById(upload.mealId);
    if (meal != null) {
      final existing = await (db.select(
        db.lowTreatmentReview,
      )..where((t) => t.occurredAt.equals(upload.eatenAt))).getSingleOrNull();
      if (existing == null) {
        await db
            .into(db.lowTreatmentReview)
            .insert(
              LowTreatmentReviewCompanion.insert(
                occurredAt: Value(upload.eatenAt),
                mealId: Value(upload.mealId),
                externalId: Value(historyId),
                dismissed: const Value(false),
              ),
            );
      } else if (existing.mealId != upload.mealId || existing.dismissed) {
        throw StateError('Carbohydrate review conflict');
      }
      await (db.update(
        db.lowTreatmentHandoff,
      )..where((t) => t.mealId.equals(upload.mealId))).write(
        LowTreatmentHandoffCompanion(
          matchedTreatAt: Value(upload.eatenAt),
          matchedExternalId: Value(historyId),
        ),
      );
    }
    await update(upload.mealId, 'sent');
  });
}
