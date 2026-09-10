import '../utils/extended_carbs_schedule_settings.dart';

class MealAdvisorConfig {
  /// Hypo threshold used for TTL (mg/dL)
  final int lowThreshold;

  /// Safety buffer added when comparing TTL vs TAF (minutes)
  final int safetyMarginMin;

  /// If TTL is within (TAF + safetyMargin .. TAF + nearWindow) => "near" zone
  final int nearWindowMin;

  /// Clamp for TAF (minutes)
  final int minTafMin;
  final int maxTafMin;

  /// Clamp for TTL (minutes)
  final int maxTtlMin;

  /// Base TAF for a "normal" carb meal (minutes)
  final double tafBaseMin;

  /// Macro weights: how many minutes each gram adds to start time (TAF).
  /// These are *heuristic*, tune them to get desired gameplay.
  final double fatMinPerGram;
  final double proteinMinPerGram;
  final double fiberMinPerGram;

  /// Caps (max minutes) for each macro contribution so one macro can't explode TAF.
  final double fatCapMin;
  final double proteinCapMin;
  final double fiberCapMin;

  /// How strongly IOB pulls trend downward (mg/dL per min per 1U IOB).
  /// Bigger = more conservative (shorter TTL).
  final double iobDropRatePerU;

  /// Optional COB support to reduce downward effective trend.
  /// If you don't trust COB, set to 0.0.
  final double cobSupportRatePerGram;

  /// BG thresholds for high/normal logic
  final int highBgThreshold;

  /// Default schedule for WBT-based extended carbs suggestions.
  final ExtendedCarbsScheduleSettings extendedCarbsScheduleSettings;

  const MealAdvisorConfig({
    this.lowThreshold = 70,
    this.safetyMarginMin = 5,
    this.nearWindowMin = 20,
    this.minTafMin = 5,
    this.maxTafMin = 45,
    this.maxTtlMin = 240,
    this.tafBaseMin = 12.0,
    this.fatMinPerGram = 0.6,
    this.proteinMinPerGram = 0.2,
    this.fiberMinPerGram = 1.0,
    this.fatCapMin = 18.0,
    this.proteinCapMin = 10.0,
    this.fiberCapMin = 12.0,
    this.iobDropRatePerU = 1.2,
    this.cobSupportRatePerGram = 0.03,
    this.highBgThreshold = 140,
    this.extendedCarbsScheduleSettings =
        const ExtendedCarbsScheduleSettings.defaults(),
  });
}
