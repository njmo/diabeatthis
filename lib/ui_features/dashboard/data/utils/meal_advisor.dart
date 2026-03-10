// A more "real-life-ish" MealAdvisor based on TTL (time-to-low) vs TAF (time-to-absorption-first).
// - TTL depends on BG + trend + IOB (optionally COB)
// - TAF depends on meal macros: carbs + fat + protein + fiber
//
// Notes:
// - `trend` is treated as mg/dL per minute (IMPORTANT). If your trend is per 5 minutes,
//   convert before calling (e.g., trendPerMin = (trendPer5Min / 5).round()).
// - This is a simulation heuristic, not medical advice.

enum MealDecision {
  eatNowBolusLater, // in this version: "eat now, no bolus now; log carbs"
  bolusAndEatNow,
  bolusWaitThenEat,
}

extension MealDecisionX on MealDecision {
  String get status => switch (this) {
    MealDecision.eatNowBolusLater => 'eating-then-bolus',
    MealDecision.bolusAndEatNow => 'bolused-eating',
    MealDecision.bolusWaitThenEat => 'bolused-waiting',
  };
}

class MealAdvice {
  final MealDecision? decision;
  final WaitSuggestion? wait;
  final DateTime? created_at;

  MealAdvice(this.decision, this.wait) : created_at = null;
  MealAdvice.full(this.decision, this.wait, this.created_at);
  MealAdvice.empty() : decision = null, wait = null, created_at = null;
}

class WaitSuggestion {
  final int recommendedMinutes; // main target time
  final int minMinutes; // lower bound of window
  final int maxMinutes; // upper bound of window

  WaitSuggestion(this.recommendedMinutes, this.minMinutes, this.maxMinutes);
}

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
  });
}

class MealAdvisor {
  final MealAdvisorConfig config;

  MealAdvisor({MealAdvisorConfig? config})
    : config = config ?? const MealAdvisorConfig();

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

    final ttl = calculateTtlMinutes(bg: bg, trend: trend, iob: iob, cob: cob);

    final decision = decide(
      bg: bg,
      trend: trend,
      iob: iob,
      tafMinutes: taf,
      ttlMinutes: ttl,
    );

    if (decision == MealDecision.bolusWaitThenEat) {
      final wait = calculateWaitTime(
        bg: bg,
        trend: trend,
        tafMinutes: taf,
        ttlMinutes: ttl,
      );
      return MealAdvice(decision, wait);
    }

    return MealAdvice(decision, null);
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
      return MealDecision.eatNowBolusLater;
    }

    // 2) Near zone: meal likely starts "just in time" — decide conservatively.
    if (ttlMinutes <= tafSafe + nearWindow) {
      // If BG is on the lower side OR IOB is sizable, stay conservative.
      final bgLowish = bg < 110;
      final highIob = iob >= 1.0;

      if (bgLowish || highIob) {
        return MealDecision.eatNowBolusLater;
      }

      // Otherwise OK to bolus & eat now.
      return MealDecision.bolusAndEatNow;
    }

    // 3) Comfortable zone: meal will start well before low.
    // Now classic logic: if BG high and not dropping, consider waiting after bolus.
    final bgHigh = bg >= config.highBgThreshold;
    final notDropping =
        trend >= 0; // raw trend (you can swap to trendEff if you prefer)

    if (bgHigh && notDropping) {
      return MealDecision.bolusWaitThenEat;
    }

    return MealDecision.bolusAndEatNow;
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
