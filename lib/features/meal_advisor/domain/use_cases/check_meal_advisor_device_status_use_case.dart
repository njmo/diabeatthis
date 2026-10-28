import 'package:clock/clock.dart';

import '../../../../core/domain/model/device_status.dart';
import '../models/meal_advice_eligibility.dart';

class CheckMealAdvisorDeviceStatusUseCase {
  const CheckMealAdvisorDeviceStatusUseCase();

  // Preserve the existing foreground expiry, now also enforced in UI.
  static const maximumAge = Duration(minutes: 6);

  MealAdviceEligibility call(DeviceStatus? status) =>
      evaluate(status, clock.now());

  MealAdviceEligibility evaluate(DeviceStatus? status, DateTime now) {
    if (status == null) return MealAdviceEligibility.missingDeviceStatus;
    final age = now.difference(status.date);
    if (age.isNegative || age >= maximumAge) {
      return MealAdviceEligibility.staleDeviceStatus;
    }
    if (!status.hasIob || !status.hasCob) {
      return MealAdviceEligibility.incompleteDeviceStatus;
    }
    // Negative net IOB is possible; a negative COB is not a valid input.
    if (!status.iob.isFinite ||
        !status.cob.isFinite ||
        status.cob < 0 ||
        status.bg <= 0) {
      return MealAdviceEligibility.invalidDeviceStatus;
    }
    return MealAdviceEligibility.available;
  }
}
