import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/meal_macro_summary.dart';
import '../models/meal_advice.dart';
import '../models/meal_advisor_config.dart';
import '../services/meal_advisor.dart';
import '../utils/extended_carbs_schedule_settings.dart';

/// Shared entry point for UI and foreground. No providers, storage or UI state.
/// Preserves the existing tick conversion and decision rules.
class GetMealAdviceUseCase {
  const GetMealAdviceUseCase();

  MealAdvice call({
    required MealMacroSummary macros,
    required DeviceStatus deviceStatus,
    required ExtendedCarbsScheduleSettings settings,
  }) {
    final cleaned = deviceStatus.tick.trim().replaceAll(',', '.');
    final tick =
        int.tryParse(cleaned) ?? int.tryParse(cleaned.replaceAll('+', '')) ?? 0;
    return MealAdvisor(
      config: MealAdvisorConfig(extendedCarbsScheduleSettings: settings),
    ).getMealAdvice(
      bg: deviceStatus.bg,
      iob: deviceStatus.iob,
      cob: deviceStatus.cob,
      trend: (tick / 5).round(),
      mealCarbs: macros.netCarbsGrams,
      fatGrams: macros.fatGrams,
      proteinGrams: macros.proteinGrams,
      fiberGrams: macros.fiberGrams,
    );
  }
}
