import '../../../../core/data_sources/nightscout/helpers/nightscout_source_key.dart';
import '../../../../core/drift/database_impl.dart';
import '../../common/models/meal_wizard_relation_type.dart';

/// Explicit user-confirmed links. No matching by proximity or carb summation.
class MealWizardLinkRepository {
  final DatabaseImpl db;
  const MealWizardLinkRepository(this.db);

  Future<void> link({
    required int mealId,
    String? localWizardId,
    String? remoteWizardId,
    String? remoteSource,
    MealWizardRelationType relationType = MealWizardRelationType.initial,
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
    );
  }

  Future<List<MealWizardLinkData>> forMeal(int mealId) =>
      db.mealWizardLinkDao.forMeal(mealId);

  Future<void> unlink(int id) => db.mealWizardLinkDao.unlink(id);
}
