import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/check_meal_advisor_device_status_use_case.dart';

/// Legacy state-machine scenarios supply eligibility independently of time fixtures.
class AvailableMealAdvisorDeviceStatus
    extends CheckMealAdvisorDeviceStatusUseCase {
  const AvailableMealAdvisorDeviceStatus();

  @override
  MealAdviceEligibility call(DeviceStatus? status) =>
      MealAdviceEligibility.available;
}
