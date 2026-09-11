import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../features/meals/common/models/meal_wizard_relation_type.dart';
import '../../../../../features/meals/data/providers/meal_wizard_recorder_provider.dart';
import '../../../base/runtime_context.dart';

class RecordMealWizardLink with Logging {
  const RecordMealWizardLink();

  Future<void> call(
    RuntimeContext context,
    BolusWizard wizard,
    int mealId, {
    MealWizardRelationType type = MealWizardRelationType.initial,
  }) async {
    try {
      // Bound waiting, not the transaction: a slow write can still finish later.
      await context.container
          .read(mealWizardRecorderProvider)(wizard, mealId, type)
          .timeout(const Duration(seconds: 2));
    } catch (error) {
      // Persistence failure must not reject an accepted calculator response.
      logW('Could not link consumed meal wizard: ${error.runtimeType}');
    }
  }
}
