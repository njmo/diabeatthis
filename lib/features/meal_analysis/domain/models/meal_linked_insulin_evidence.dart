import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/domain/model/manual_bolus.dart';
import '../../../meals/common/models/meal_wizard_relation_type.dart';

enum MealBolusAssociation {
  historyUnavailable,
  calculatorMissing,
  calculatorAmbiguous,
  noRecordedBolusCandidate,
  bolusCandidateAmbiguous,
  temporalAmountCandidate,
}

class MealLinkedInsulinEvidence {
  final MealWizardRelationType role;
  final DateTime? assignedAt;
  final BolusWizard? calculator;
  final ManualBolus? bolusCandidate;
  final MealBolusAssociation association;
  final int? candidateCount;
  const MealLinkedInsulinEvidence({
    required this.role,
    required this.assignedAt,
    required this.calculator,
    required this.bolusCandidate,
    required this.association,
    required this.candidateCount,
  });
}
