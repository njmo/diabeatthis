# Meal Advisor architecture and regression review

## Scope

Review of the accumulated Meal Advisor, source-history, persistence, meal-history and foreground changes against pre-change commit `9360919a47f17a5da047f9fa89545c2d116a113b`. This is a code and automated-test review; no phone was operated and no insulin/treatment action was sent.

## Findings fixed

1. **Late reminder scheduling could overwrite a newer choice or access a disposed provider.** `chooseEat` already checked request identity after history loading but missed the final notification await. It now checks both `ref.mounted` and request identity there. Tests suspend scheduling, then skip or dispose the dialog controller.
2. **Confirmation could validate one advice and save another.** The CGM await previously resumed against mutable state. Confirmation now captures the advice, input status and request identity, and refuses a superseded operation without clearing the newer state. The UI handles this as an unfinished confirmation instead of closing with a saved result. Tests cover both successful/failed late validation, switching to a manual decision, and the dialog's saving/cancellation state.
3. **Migration coverage did not demonstrate preservation of non-default extended-carb settings.** Migration tests for versions 17–22 now preserve nonzero grams, delivery mode, delay, duration, reason, original timestamp and wait values, as well as verifying the synchronization trigger and removal of the obsolete JSON column.
4. **A new history row used the global locale for existing reason labels.** It now passes the widget's localization explicitly.

## Architecture assessment

- Calculation and freshness policy live under `features/meal_advisor/domain`; `GetMealAdviceUseCase` does not depend on Riverpod, widgets or Drift. Provider definitions are composition adapters. UI and foreground use the same calculation and eligibility implementations.
- Clock access uses the existing injectable `clock` package. Freshness is checked at the completion of asynchronous history fetches; acceptance validates both the original status and the current status. Manual decisions remain available independently of automatic eligibility.
- Result persistence is separate from calculation and presentation. The existing reason/version/timestamp are retained without constructing or persisting input/configuration JSON. Source prediction/activity data remain in device history.
- Meal history widgets render supplied analysis; new low-treatment data are fetched once by the analysis path and reused by the timeline and comparison. The repository reuses existing meal ingredient/history mapping rather than introducing a second nutritional calculation.
- Common decision labels and existing nutrition/history helpers are reused. Meal-specific orchestration remains within feature folders. The dashboard compatibility export preserves existing imports during the transition.
- No new private widget classes or speculative general-purpose framework were added. The removed trace/provider/analyzer chain has no remaining production or test references.

## Preserved behavior and intentional changes

- The prior audit compared 3,600 input combinations against the pre-refactor calculator: decisions, wait bounds, e-carbs grams and schedule timing matched. This review does not modify those formulas.
- Existing meal actions, manual choices, pending-save protection, accepted-result storage and foreground monitoring remain covered by tests.
- Linked low-treatment sections and rich linked timeline entries remain, including previously displayed entries outside the generic analysis window. Window-based unlinked entries supplement them and are deduplicated by source record identity; no IDs are added to stored advice.
- Automatic advice availability is intentionally stricter for missing/stale data. Rise-display timestamp tolerance and manual-bolus labels are intentional changes from the earlier work, not part of the calculation formula.
- Removing the stored JSON explanation and its dedicated display was explicitly requested. This is the one deliberately removed display/persistence feature; it is not a claim that every intermediate experimental feature was retained.

## Next architecture boundary

The existing `AnalyzeMealUseCase` is still a Riverpod/Drift-aware orchestrator, as it was before this work. It is not yet the proposed pure `BeforeMealContext`/`MealOutcomeContext` builder. That extraction should be the next separate change: keep history acquisition in adapters, construct immutable context from supplied records and explicit time bounds, and leave recommendation/LLM interpretation outside the builders. Historical reconstruction must not claim later edits were available when the original advice was made.

## Validation

Final project test and static-analysis results are recorded in `meal-advisor-changes.md` after completion. The new tests use controlled futures and actual SQLite migrations; they do not drive a phone or copy real patient data.
