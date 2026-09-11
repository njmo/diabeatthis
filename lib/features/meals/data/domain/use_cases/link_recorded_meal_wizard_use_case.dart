import '../../../../../core/data_sources/config/data_source_config.dart';
import '../../../../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../../../../core/domain/model/bolus_wizard.dart' as domain;
import '../../../../../core/drift/database_impl.dart';
import '../../../common/models/meal_wizard_relation_type.dart';
import '../../repositories/meal_wizard_link_repository.dart';

/// The monitor already identified the wizard as the active meal's response.
class LinkRecordedMealWizardUseCase {
  final DatabaseImpl db;
  final Future<TreatmentsSource> Function() loadSource;

  const LinkRecordedMealWizardUseCase(this.db, {required this.loadSource});

  Future<void> call(
    domain.BolusWizard wizard,
    int mealId, {
    MealWizardRelationType type = MealWizardRelationType.initial,
  }) async {
    if (!wizard.isValid) return;
    final remoteId = wizard.remoteSource == null
        ? null
        : wizard.nightscoutObjectId;
    // A live AAPS event may lack IDs even with mirroring enabled. Persist only
    // this consumed event to give its meal link a stable identity.
    final source = wizard.localId == null && remoteId == null
        ? await loadSource()
        : null;
    await db.transaction(() async {
      var localId = wizard.localId;
      if (source != null) {
        final stored = await db.localMirrorDao.upsertBolusWizard(
          wizard.toCompanion(source),
        );
        localId = stored.localId;
      }
      await MealWizardLinkRepository(db).link(
        mealId: mealId,
        localWizardId: localId,
        remoteWizardId: remoteId,
        remoteSource: remoteId == null ? null : wizard.remoteSource,
        relationType: type,
      );
    });
  }
}
