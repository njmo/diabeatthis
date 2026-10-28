import '../../../../core/data_sources/nightscout/helpers/nightscout_source_key.dart';
import '../../../../core/domain/model/bolus_wizard.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../../common/models/meal_wizard_assignment.dart';
import '../../common/models/meal_wizard_relation_type.dart';

/// Persists confirmed links and explicit dismissals. Matching belongs to use cases.
class MealWizardLinkRepository {
  final DatabaseImpl db;
  const MealWizardLinkRepository(this.db);

  Future<void> link({
    required int mealId,
    String? localWizardId,
    String? remoteWizardId,
    String? remoteSource,
    MealWizardRelationType relationType = MealWizardRelationType.initial,
    bool automatic = false,
  }) async {
    if (localWizardId == null && remoteWizardId == null) {
      throw ArgumentError('A wizard identity is required');
    }
    if ((remoteWizardId == null) != (remoteSource == null) ||
        remoteWizardId?.trim().isEmpty == true) {
      throw ArgumentError('A remote identity requires an ID and a source');
    }
    final source = remoteSource == null
        ? null
        : nightscoutSourceKey(remoteSource);
    await db.mealWizardLinkDao.link(
      mealId: mealId,
      localWizardId: localWizardId,
      remoteWizardId: remoteWizardId,
      source: source,
      relationType: relationType.name,
      automatic: automatic,
    );
  }

  Future<List<MealWizardAssignment>> forWizards(
    List<domain.BolusWizard> wizards,
  ) async {
    final rows = await db.mealWizardLinkDao.forWizardIds(
      localIds: wizards
          .map((w) => w.localId)
          .whereType<String>()
          .toSet()
          .toList(),
      remoteIds: wizards
          .map((w) => w.nightscoutObjectId)
          .whereType<String>()
          .toSet()
          .toList(),
    );
    return rows
        .map(_assignment)
        .where((link) => wizards.any(link.matches))
        .toList();
  }

  Future<List<MealWizardAssignment>> assignmentsForMeal(int mealId) async =>
      (await forMeal(mealId)).map(_assignment).toList();

  MealWizardAssignment _assignment(MealWizardLinkData row) =>
      MealWizardAssignment(
        id: row.id,
        dismissed: row.dismissed,
        mealId: row.mealId,
        localId: row.localWizardId,
        remoteId: row.remoteWizardId,
        remoteSource: row.remoteSource,
        type: MealWizardRelationType.values.byName(row.relationType),
        recordedAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      );

  Future<List<MealWizardLinkData>> forMeal(int mealId) =>
      db.mealWizardLinkDao.forMeal(mealId);

  Future<void> unlink(int id) => db.mealWizardLinkDao.unlink(id);
}
