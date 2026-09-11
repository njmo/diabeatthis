import '../../../../core/domain/model/bolus_wizard.dart';
import 'meal_wizard_relation_type.dart';

class MealWizardAssignment {
  final bool dismissed;
  final int id;
  final int mealId;
  final String? localId;
  final String? remoteId;
  final String? remoteSource;
  final MealWizardRelationType type;

  const MealWizardAssignment({
    this.dismissed = false,
    required this.id,
    required this.mealId,
    required this.localId,
    required this.remoteId,
    required this.remoteSource,
    required this.type,
  });

  bool matches(BolusWizard wizard) =>
      (localId != null && localId == wizard.localId) ||
      (remoteId != null &&
          remoteSource != null &&
          remoteId == wizard.nightscoutObjectId &&
          remoteSource == wizard.remoteSource);
}
