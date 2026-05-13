import 'extended_carbs_schedule_settings.dart';

class WbtExtendedCarbsSuggestion {
  final double kcal;
  final double wbt;
  final int grams;
  final ExtendedCarbsScheduleSettings scheduleSettings;

  const WbtExtendedCarbsSuggestion({
    required this.kcal,
    required this.wbt,
    required this.grams,
    this.scheduleSettings = const ExtendedCarbsScheduleSettings.defaults(),
  });

  const WbtExtendedCarbsSuggestion.none()
    : kcal = 0,
      wbt = 0,
      grams = 0,
      scheduleSettings = const ExtendedCarbsScheduleSettings.defaults();

  bool get shouldSuggest => grams > 0;

  WbtExtendedCarbsSuggestion withSchedule(
    ExtendedCarbsScheduleSettings settings,
  ) {
    return WbtExtendedCarbsSuggestion(
      kcal: kcal,
      wbt: wbt,
      grams: grams,
      scheduleSettings: settings,
    );
  }
}

class WbtExtendedCarbsCalculator {
  static const double kcalPerWbt = 100;
  static const double carbsGramsPerWbt = 10;
  static const double minSuggestedWbt = 1;

  const WbtExtendedCarbsCalculator();

  WbtExtendedCarbsSuggestion calculateFromMacros({
    required double fatGrams,
    required double proteinGrams,
  }) {
    return calculateFromKcal(proteinGrams * 4 + fatGrams * 9);
  }

  WbtExtendedCarbsSuggestion calculateFromKcal(double kcal) {
    final normalizedKcal = kcal < 0 ? 0.0 : kcal;
    final wbt = normalizedKcal / kcalPerWbt;
    final grams = wbt > minSuggestedWbt ? (wbt * carbsGramsPerWbt).round() : 0;

    return WbtExtendedCarbsSuggestion(
      kcal: normalizedKcal,
      wbt: wbt,
      grams: grams,
    );
  }
}
