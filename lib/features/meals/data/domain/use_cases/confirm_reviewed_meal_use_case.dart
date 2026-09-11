import 'package:clock/clock.dart';

import '../../../../../core/domain/model/bolus_wizard.dart' as domain;
import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/logger/logger.dart';
import '../../../common/models/meal_wizard_relation_type.dart';
import '../../models/meal_review_timing.dart';
import '../../persistence/record_retrospective_meal_history.dart';
import '../../repositories/meal_wizard_link_repository.dart';

class ConfirmReviewedMealUseCase {
  final DatabaseImpl db;
  final MealWizardLinkRepository links;

  const ConfirmReviewedMealUseCase(this.db, this.links);

  /// Confirming an unstarted meal records eating without completing its summary.
  /// Status and assignment are committed together so a failed link changes neither.
  Future<bool> call({
    required domain.BolusWizard wizard,
    required int mealId,
    required MealWizardRelationType relationType,
    MealReviewTiming? timing,
  }) => db.transaction(() async {
    Log.i(
      'ConfirmReviewedMealUseCase',
      'Review link start: mealId=$mealId, relation=${relationType.name}, localIdPresent=${wizard.localId != null}, remoteIdPresent=${wizard.nightscoutObjectId != null}, sourcePresent=${wizard.remoteSource != null}, timingPresent=${timing != null}',
    );
    await links.link(
      mealId: mealId,
      localWizardId: wizard.localId,
      remoteWizardId: wizard.remoteSource == null
          ? null
          : wizard.nightscoutObjectId,
      remoteSource: wizard.nightscoutObjectId == null
          ? null
          : wizard.remoteSource,
      relationType: relationType,
    );
    final meal = await db.mealDao.getMealById(mealId);
    if (meal == null) throw StateError('Meal is unavailable');
    Log.i(
      'ConfirmReviewedMealUseCase',
      'Review relation written: mealId=$mealId, status=${meal.status}',
    );
    if (meal.status != 'planned' && meal.status != 'skipped') return false;
    if (timing == null) throw ArgumentError('Meal timing is required');
    timing.timing.validate(timing.startedAt, clock.now());
    Log.i(
      'ConfirmReviewedMealUseCase',
      'Review timing validated: mealId=$mealId, decision=${timing.timing.choice.decision.name}, startedAt=${timing.startedAt}, eatingMinutes=${timing.timing.eatingMinutes}, waitMinutes=${timing.timing.choice.waitMinutes}, bolusAfterStartMinutes=${timing.timing.bolusAfterStartMinutes}',
    );
    await db.mealDao.clearInterruptedEatingHistory(mealId);
    await recordRetrospectiveMealHistory(
      db,
      mealId,
      timing.timing,
      timing.startedAt,
      summarize: false,
    );
    Log.i(
      'ConfirmReviewedMealUseCase',
      'Review history written: mealId=$mealId',
    );
    return true;
  });
}
