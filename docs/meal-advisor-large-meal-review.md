# Large-meal decision review

This review characterizes algorithm version 2. The cases below are synthetic software fixtures, not observations from a user's meal history or validated treatment recommendations. Production decisions are unchanged by this stage.

## Reproduced behavior

Inputs use BG in mg/dL, trend in mg/dL/min, IOB in U and macros in grams. COB is zero in these cases.

| Case | Inputs | Current computed values | Current output |
| --- | --- | --- | --- |
| Small meal, high flat BG | BG 180, trend 0, IOB 2; carbs/fat/protein/fiber 40/0/0/0 | TAF 12, TTL 46 | Bolus, wait, eat |
| Mixed large meal, same glucose context | BG 180, trend 0, IOB 2; 100/30/50/10 | TAF 45, TTL 46 | Eat, bolus later: low-before-meal branch |
| Large meal without IOB | BG 180, trend 0, IOB 0; 100/30/50/10 | TAF 45, TTL 240 | Bolus, wait, eat |
| High falling BG | BG 220, trend -1, IOB 0; 100/30/50/10 | TAF 45, TTL 150 | Bolus and eat immediately |
| High rising BG in near zone | BG 180, trend +1, IOB 3; 100/20/30/5 | TAF 35, TTL 42 | Eat, bolus later: near-low and IOB branch |
| Decimal falling tick through shared use case | BG 220, IOB 0, tick -7.5 or -7,5; 100/30/50/10 | Parsed trend 0, TTL 240 | Bolus, wait, eat |

Increasing carbohydrate amount alone from 10 to 200 grams, keeping the other macros fixed, leaves TAF and the timing decision unchanged. TAF uses carbohydrate amount only for the below-10-gram adjustment. Absolute fat/protein/fiber quantities increase TAF up to its cap. Therefore the symptom concerns meal composition and IOB together, rather than every large meal.

TTL uses `trend - 1.2 * IOB + 0.03 * COB`. It does not use insulin sensitivity, insulin type, model activity or a future glucose curve. This review does not establish the physiological accuracy of that formula. Total IOB and current trend are not independent measurements of future glucose change; assess potential overlapping effects before introducing additional activity-based terms.

Decision precedence explains the outputs: TTL/TAF comparison first, near-low rule second, and high-BG waiting rule only afterward. In the last rule, any negative integer trend prevents waiting. Changing high-BG priority alone would bypass the preceding checks.

## Proposed correction sequence and before/after contract

1. **Repair trend input handling in a separate change.** Replace integer parsing and early rounding with explicit finite decimal parsing, carrying precision through the calculation. Verify the upstream tick interval before retaining the current division by five. Currently a decimal falling tick becomes zero; afterward it must remain falling. Missing or malformed input should be explicitly unavailable rather than represented as a measured flat trend. Connect that state to both UI and foreground eligibility and acceptance checks. Test units, sign, comma/dot decimals, missing data, NaN/infinity and the current integer boundaries. Update trace algorithm version and preserve old trace decoding. Exact timing outputs must be reviewed because removing rounding changes branch boundaries.
2. **Separate meal onset assumptions from later mixed-meal absorption.** Currently absolute fat/protein/fiber additions directly delay the modeled first effect and can switch the whole meal to delayed bolus. Evaluate an explicit early-carbohydrate component separately from the existing WBT extended-carbs schedule. Afterward a larger mixed meal should expose which assumption caused its timing result; no numerical onset coefficients or alternative bolus timing are approved or implemented here. A reduced TAF cap alone would be an arbitrary dosing-rule change.
3. **Replace unsupported future-risk inference only with validated inputs.** Currently the IOB multiplier can activate the delayed-bolus branch even at high/rising BG. Evaluate timestamped AAPS predictions, their availability, meaning and completeness as a separate input contract before choosing any thresholds. Descriptive recent total insulin activity remains descriptive. Do not infer an individual bolus peak from it, and do not let predictions bypass the existing CGM freshness requirement.
4. **Compare candidate decisions offline before activation.** Replay identical saved inputs/configuration through old and candidate versions; record changed reason, timing, input validity and manual fallback. Evaluate meal-history outcomes separately, accounting for what the user actually did, corrections and activity. A retrospective outcome alone cannot prove which alternative advice would have been correct. No available local meal dataset was read in this stage.

This stage intentionally provides reproducible current outputs and a correction contract, not invented numerical “after” recommendations. The agreed sequence was to propose a correction before changing recommendations. Next implement input handling first, then review the scenario diff before activation of changes to the timing model.

## Verification

The characterization suite lives in `test/features/meal_advisor/domain/services/meal_advisor_large_meal_test.dart`. It exercises the shared engine/use case used by UI and foreground, including exact safety/near-low boundaries. These assertions document current behavior and should be deliberately updated when the algorithm changes; they are not clinical acceptance criteria.
