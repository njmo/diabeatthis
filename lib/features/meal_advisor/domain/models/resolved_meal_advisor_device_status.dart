import '../../../../core/domain/model/device_status.dart';
import 'meal_advice_eligibility.dart';

class ResolvedMealAdvisorDeviceStatus {
  const ResolvedMealAdvisorDeviceStatus({
    this.status,
    required this.eligibility,
  });

  /// Only a currently usable snapshot is exposed to the meal calculation.
  final DeviceStatus? status;
  final MealAdviceEligibility eligibility;
}
