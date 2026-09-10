import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/check_meal_advice_eligibility_use_case.dart';

/// Workflow tests supply eligibility independently of history transport.
class AvailableMealAdviceEligibility extends CheckMealAdviceEligibilityUseCase {
  AvailableMealAdviceEligibility()
    : super(loadRepository: () => throw UnimplementedError());

  MealAdviceEligibility result = MealAdviceEligibility.available;

  Future<MealAdviceEligibility>? pendingResult;

  @override
  Future<MealAdviceEligibility> call() async =>
      pendingResult == null ? result : await pendingResult!;
}
