import '../../data/models/meal_details_data.dart';
import '../models/meal_ecarbs_proposal.dart';

/// Describes the stored proposal only; it never implies delivery to AAPS.
class BuildMealEcarbsProposalUseCase {
  const BuildMealEcarbsProposalUseCase();

  MealEcarbsProposal call(MealDetailsData details) {
    final decision = details.advisorDecision;
    final delay = decision?.extendedCarbsDelayMinutes;
    final duration = decision?.extendedCarbsDurationMinutes;
    final grams = decision?.extendedCarbsGrams;
    return MealEcarbsProposal(
      hasDecision: decision != null,
      kind: switch (decision?.extendedCarbsDeliveryMode) {
        'extraBolus' => MealEcarbsProposalKind.extraBolus,
        'extendedCarbs' => MealEcarbsProposalKind.extendedCarbs,
        _ => MealEcarbsProposalKind.unknown,
      },
      grams: grams != null && grams > 0 ? grams : null,
      delayMinutes: delay != null && delay >= 0 ? delay : null,
      durationMinutes: duration != null && duration > 0 ? duration : null,
    );
  }
}
