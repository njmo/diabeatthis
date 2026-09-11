import 'package:drift/drift.dart';

import '../database_impl.dart';
import '../models/wizard_identity_conflict.dart';

part 'meal_wizard_link_dao.g.dart';

@DriftAccessor(include: {'../schemas/schema.drift'})
class MealWizardLinkDao extends DatabaseAccessor<DatabaseImpl>
    with _$MealWizardLinkDaoMixin {
  MealWizardLinkDao(super.db);

  Future<void> link({
    required int mealId,
    String? localWizardId,
    String? remoteWizardId,
    String? source,
    required String relationType,
    bool automatic = false,
  }) async {
    await transaction(() async {
      BolusWizardData? wizard;
      if (localWizardId != null) {
        wizard = await (db.select(
          db.bolusWizard,
        )..where((row) => row.localId.equals(localWizardId))).getSingle();
        if (remoteWizardId != null &&
            (wizard.nightscoutId != remoteWizardId ||
                wizard.remoteSource != source)) {
          throw WizardIdentityConflict(
            'Local and remote wizard identity has not been verified',
          );
        }
      } else if (remoteWizardId != null) {
        wizard =
            await (db.select(db.bolusWizard)..where(
                  (row) =>
                      row.nightscoutId.equals(remoteWizardId) &
                      row.remoteSource.equals(source!),
                ))
                .getSingleOrNull();
      }
      if (wizard != null) await _reconcile(wizard);
      final localId = wizard?.localId;
      final remoteId =
          remoteWizardId ??
          (wizard?.remoteSource == null ? null : wizard?.nightscoutId);
      final resolvedSource =
          source ?? (remoteId == null ? null : wizard?.remoteSource);
      final table = db.mealWizardLink;
      final existing = await _matchingLinks(
        localId,
        remoteId,
        resolvedSource,
      ).getSingleOrNull();
      if (automatic) {
        // A dismissed row is deliberately retained to prevent recreation.
        if (existing != null) return;
        final assigned =
            await (db.select(table)..where(
                  (row) =>
                      row.mealId.equals(mealId) & row.dismissed.equals(false),
                ))
                .get();
        if (assigned.isNotEmpty) return;
      }
      if (existing != null &&
          !existing.dismissed &&
          existing.mealId != mealId) {
        throw WizardIdentityConflict(
          'Wizard is already linked to another meal',
        );
      }
      final values = MealWizardLinkCompanion.insert(
        mealId: mealId,
        localWizardId: Value(localId),
        remoteWizardId: Value(remoteId),
        remoteSource: Value(resolvedSource),
        relationType: relationType,
        dismissed: const Value(false),
      );
      if (existing == null) {
        await db.into(table).insert(values);
      } else {
        await (db.update(
          table,
        )..where((row) => row.id.equals(existing.id))).write(values);
      }
    });
  }

  SimpleSelectStatement<MealWizardLink, MealWizardLinkData> _matchingLinks(
    String? localId,
    String? remoteId,
    String? source,
  ) => db.select(db.mealWizardLink)
    ..where(
      (row) =>
          (localId == null
              ? const Constant(false)
              : row.localWizardId.equals(localId)) |
          (remoteId == null
              ? const Constant(false)
              : row.remoteWizardId.equals(remoteId) &
                    row.remoteSource.equals(source!)),
    )
    ..orderBy([(row) => OrderingTerm.asc(row.id)]);

  Future<void> reconcile(BolusWizardData wizard) =>
      transaction(() => _reconcile(wizard));

  Future<void> _reconcile(BolusWizardData wizard) async {
    final remoteId = wizard.nightscoutId;
    final source = wizard.remoteSource;
    if (remoteId == null || source == null) return;
    final table = db.mealWizardLink;
    final links = await _matchingLinks(wizard.localId, remoteId, source).get();
    if (links.isEmpty) return;
    final first =
        links.where((link) => !link.dismissed).firstOrNull ?? links.first;
    for (final link in links) {
      if ((!link.dismissed &&
              !first.dismissed &&
              (link.mealId != first.mealId ||
                  link.relationType != first.relationType)) ||
          (link.remoteWizardId != null &&
              (link.remoteWizardId != remoteId ||
                  link.remoteSource != source)) ||
          (link.localWizardId != null &&
              link.localWizardId != wizard.localId)) {
        throw WizardIdentityConflict(
          'Conflicting meal links for a wizard identity',
        );
      }
    }
    for (final duplicate in links.where((link) => link.id != first.id)) {
      await (db.delete(
        table,
      )..where((row) => row.id.equals(duplicate.id))).go();
    }
    await (db.update(table)..where((row) => row.id.equals(first.id))).write(
      MealWizardLinkCompanion(
        localWizardId: Value(wizard.localId),
        remoteWizardId: Value(remoteId),
        remoteSource: Value(source),
      ),
    );
  }

  Future<List<MealWizardLinkData>> forWizardIds({
    required List<String> localIds,
    required List<String> remoteIds,
  }) {
    if (localIds.isEmpty && remoteIds.isEmpty) return Future.value([]);
    return (db.select(db.mealWizardLink)..where(
          (row) =>
              row.localWizardId.isIn(localIds) |
              row.remoteWizardId.isIn(remoteIds),
        ))
        .get();
  }

  Future<List<MealWizardLinkData>> forMeal(int mealId) =>
      (db.select(db.mealWizardLink)..where(
            (row) => row.mealId.equals(mealId) & row.dismissed.equals(false),
          ))
          .get();

  Future<void> unlink(int id) async {
    await (db.update(db.mealWizardLink)..where((row) => row.id.equals(id)))
        .write(const MealWizardLinkCompanion(dismissed: Value(true)));
  }
}
