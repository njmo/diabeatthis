import '../../../../common/meal/manual_meal_decision.dart';
import '../../../../common/meal/meal_decision.dart';
import '../../../../core/domain/model/bolus_wizard.dart';
import '../../data/models/meal_analysis_data.dart';
import '../../data/models/meal_details_data.dart';
import '../../domain/models/meal_application_review.dart';
import '../../domain/models/meal_ecarbs_proposal.dart';
import '../../domain/models/meal_origin_review.dart';
import '../../domain/models/meal_save_event.dart';
import '../../domain/use_cases/build_meal_application_review_use_case.dart';
import '../../domain/use_cases/build_meal_ecarbs_proposal_use_case.dart';
import '../../domain/use_cases/build_meal_origin_use_case.dart';
import '../../domain/use_cases/build_meal_save_timeline_use_case.dart';
import '../../domain/use_cases/select_meal_calculators_use_case.dart';
import '../models/meal_page_state.dart';

class MealApplicationReviewController {
  const MealApplicationReviewController({
    this.review = const BuildMealApplicationReviewUseCase(),
    this.saveTimeline = const BuildMealSaveTimelineUseCase(),
    this.originReview = const BuildMealOriginUseCase(),
    this.ecarbsProposal = const BuildMealEcarbsProposalUseCase(),
    this.calculators = const SelectMealCalculatorsUseCase(),
  });
  final BuildMealApplicationReviewUseCase review;
  final BuildMealSaveTimelineUseCase saveTimeline;
  final BuildMealOriginUseCase originReview;
  final SelectMealCalculatorsUseCase calculators;
  final BuildMealEcarbsProposalUseCase ecarbsProposal;
  MealEcarbsProposal proposedEcarbs(MealDetailsData details) =>
      ecarbsProposal(details);

  MealApplicationReview build(MealPageState state) =>
      review(state.details, state.analysis);
  List<MealSaveEvent> savedEvents(MealDetailsData details) =>
      saveTimeline(details);
  MealOriginReview? origin(MealDetailsData details) => originReview(details);
  List<BolusWizard> availableCalculators(MealAnalysisData analysis) =>
      calculators.available(analysis);
  bool isAssignedCalculator(MealDetailsData details, BolusWizard wizard) =>
      calculators.isAssigned(details, wizard);
  MealDecision manualChoice(MealDetailsData details) =>
      manualMealDecisionFromHistory(
        details.statusHistory.map((entry) => entry.status),
        selectedWaitMinutes: details.advisorDecision?.initialWaitTime ?? 0,
      );
}
