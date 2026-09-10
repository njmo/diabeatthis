import '../../../../common/meal/meal_decision.dart';
import '../models/meal_advice.dart';
import '../models/meal_advice_reason.dart';
import '../models/meal_advisor_config.dart';
import '../models/wait_suggestion.dart';
import '../utils/extended_carbs_schedule_settings.dart';
import '../utils/wbt_extended_carbs_calculator.dart';

class MealAdvisor {
  static const algorithmVersion = 2;
  final MealAdvisorConfig config;

  MealAdvisor({MealAdvisorConfig? config})
    : config = config ?? const MealAdvisorConfig();

  // TODO: Accept post-meal context here when MealAdvisor starts analyzing
  // delayed AAPS entries after summary, for example AAPS carbs/e-carbs, time
  // since meal, BG, IOB and COB. Today this only exposes configured schedule.
  ExtendedCarbsScheduleSettings getPostMealExtendedCarbsScheduleSettings() {
    return config.extendedCarbsScheduleSettings.copyWith(
      deliveryMode: ExtendedCarbsDeliveryMode.extendedCarbs,
    );
  }

  MealAdvice getMealAdvice({
    required int bg,
    required double iob,
    required double cob,
    required int trend, // mg/dL per minute
    required double mealCarbs, // grams
    required double fatGrams, // grams
    required double proteinGrams, // grams
    required double fiberGrams, // grams
  }) {
    final taf = calculateTafMinutes(
      carbsG: mealCarbs,
      fatG: fatGrams,
      proteinG: proteinGrams,
      fiberG: fiberGrams,
    );
    final extendedCarbsScheduleSettings = config.extendedCarbsScheduleSettings
        .copyWith(deliveryMode: ExtendedCarbsDeliveryMode.extendedCarbs);
    final extendedCarbs = const WbtExtendedCarbsCalculator()
        .calculateFromMacros(fatGrams: fatGrams, proteinGrams: proteinGrams)
        .withSchedule(extendedCarbsScheduleSettings);

    final ttl = calculateTtlMinutes(bg: bg, trend: trend, iob: iob, cob: cob);

    final reason = decideReason(
      bg: bg,
      trend: trend,
      iob: iob,
      tafMinutes: taf,
      ttlMinutes: ttl,
    );

    final decision = reason.decision;
    if (decision == MealDecision.bolusWaitThenEat) {
      final wait = calculateWaitTime(
        bg: bg,
        trend: trend,
        tafMinutes: taf,
        ttlMinutes: ttl,
      );
      return MealAdvice(
        decision,
        wait,
        extendedCarbs: extendedCarbs,
        reason: reason,
      );
    }

    return MealAdvice(
      decision,
      null,
      extendedCarbs: extendedCarbs,
      reason: reason,
    );
  }

  /// Time-to-absorption-first (TAF): when carbs start noticeably affecting BG.
  int calculateTafMinutes({
    required double carbsG,
    required double fatG,
    required double proteinG,
    required double fiberG,
  }) {
    // Base time (mostly about "normal carbs"). You can optionally adjust base
    // slightly for extremely low-carb meals (start effect is less noticeable).
    var base = config.tafBaseMin;

    if (carbsG < 10) {
      base += 3; // tiny carb amount tends to have weaker/less noticeable start
    }
    final df = (fatG * config.fatMinPerGram).clamp(0.0, config.fatCapMin);
    final dp = (proteinG * config.proteinMinPerGram).clamp(
      0.0,
      config.proteinCapMin,
    );
    final dfi = (fiberG * config.fiberMinPerGram).clamp(
      0.0,
      config.fiberCapMin,
    );

    final taf = (base + df + dp + dfi).round();
    return taf.clamp(config.minTafMin, config.maxTafMin);
  }

  /// Time-to-low (TTL): minutes until BG reaches LOW threshold under effective downward trend.
  int calculateTtlMinutes({
    required int bg,
    required int trend, // mg/dL per minute
    required double iob,
    required double cob,
  }) {
    // Effective trend: current trend minus IOB-driven downward pull plus (optional) COB support.
    final extraDrop = config.iobDropRatePerU * iob;
    final cobSupport = config.cobSupportRatePerGram * cob;
    final trendEff = trend - extraDrop + cobSupport;

    if (bg <= config.lowThreshold) return 0;

    // If trend is not downward, TTL is effectively "very large"
    if (trendEff >= -0.1) {
      return config.maxTtlMin;
    }

    final delta = bg - config.lowThreshold;
    final ttl = (delta / (-trendEff)).round();
    return ttl.clamp(0, config.maxTtlMin);
  }

  MealDecision decide({
    required int bg,
    required int trend,
    required double iob,
    required int tafMinutes,
    required int ttlMinutes,
  }) => decideReason(
    bg: bg,
    trend: trend,
    iob: iob,
    tafMinutes: tafMinutes,
    ttlMinutes: ttlMinutes,
  ).decision;

  MealAdviceReason decideReason({
    required int bg,
    required int trend, // mg/dL per minute
    required double iob,
    required int tafMinutes,
    required int ttlMinutes,
  }) {
    final margin = config.safetyMarginMin;
    final nearWindow = config.nearWindowMin;

    final tafSafe = tafMinutes + margin;

    // 1) Safety override: low may happen before meal starts working.
    if (ttlMinutes <= tafSafe) {
      // "Eat now, no bolus now; log carbs"
      return MealAdviceReason.lowBeforeMealEffect;
    }

    // 2) Near zone: meal likely starts "just in time" — decide conservatively.
    if (ttlMinutes <= tafSafe + nearWindow) {
      // If BG is on the lower side OR IOB is sizable, stay conservative.
      final bgLowish = bg < 110;
      final highIob = iob >= 1.0;

      if (bgLowish || highIob) {
        return MealAdviceReason.nearLowWithLowBgOrIob;
      }

      // Otherwise OK to bolus & eat now.
      return MealAdviceReason.nearLowImmediateMeal;
    }

    // 3) Comfortable zone: meal will start well before low.
    // Now classic logic: if BG high and not dropping, consider waiting after bolus.
    final bgHigh = bg >= config.highBgThreshold;
    final notDropping =
        trend >= 0; // raw trend (you can swap to trendEff if you prefer)

    if (bgHigh && notDropping) {
      return MealAdviceReason.highBgNotFalling;
    }

    return MealAdviceReason.immediateMeal;
  }

  /// Wait suggestion for bolusWaitThenEat.
  /// A simple, consistent approach: longer waits when TTL-TAF gap is large, BG is high, and trend is rising.
  WaitSuggestion calculateWaitTime({
    required int bg,
    required int trend, // mg/dL per minute
    required int tafMinutes,
    required int ttlMinutes,
  }) {
    // Base wait derived from "how much time cushion we have before low vs meal start".
    final cushion = (ttlMinutes - tafMinutes).clamp(0, config.maxTtlMin);

    // Start from proportional cushion (but capped by our 5–15 gameplay window).
    var wait = 0.4 * cushion; // heuristic

    // BG correction (higher BG -> slightly longer wait)
    if (bg >= 180) {
      wait += 3;
    } else if (bg >= 150) {
      wait += 2;
    } else if (bg >= 140) {
      wait += 1;
    }

    // Trend correction
    if (trend >= 10) {
      wait += 2;
    } else if (trend >= 5) {
      wait += 1;
    }
    // Clamp into 5–15 minutes like your earlier design.
    final rec = wait.round().clamp(5, 15);

    return WaitSuggestion(rec, (rec - 5).clamp(0, 15), (rec + 5).clamp(5, 20));
  }
}
