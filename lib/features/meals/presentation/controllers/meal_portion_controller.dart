import '../../data/models/meal_details_data.dart';
import '../../domain/use_cases/build_meal_portion_use_case.dart';

/// Synchronous projection of already-loaded details; no second data fetch.
class MealPortionController {
  const MealPortionController({
    this.buildPortion = const BuildMealPortionUseCase(),
  });
  final BuildMealPortionUseCase buildPortion;

  MealPortionSummary build(MealDetailsData details) => buildPortion(details);
}
