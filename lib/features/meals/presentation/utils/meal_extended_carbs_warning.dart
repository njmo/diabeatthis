import '../../../../core/domain/model/extended_carb.dart';
import '../../data/models/meal_analysis_data.dart';
import '../../data/models/meal_details_data.dart';

bool shouldShowMissingExtendedCarbsWarning({
  required MealDetailsData details,
  required MealAnalysisData? analysis,
}) {
  final snapshot = details.preferredSummarySnapshot;
  if (snapshot == null || snapshot.wbtKcal <= 100 || analysis == null) {
    return false;
  }

  return !analysis.treatments.any((treatment) => treatment is ExtendedCarb);
}
