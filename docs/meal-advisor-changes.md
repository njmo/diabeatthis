# Meal Advisor work log

Entries record development chronologically; later cleanup/review entries supersede earlier implementation notes. The comparison baseline is `9360919a47f17a5da047f9fa89545c2d116a113b`.

## Scope and status

This file tracks the ongoing Meal Advisor changes and their consequences. The final changes are organized into five commits: source data, shared calculation, validation and asynchronous control, meal history, and rise detection/wording. Dose/activity personalization and changes to the TTL/TAF algorithm are not implemented.

## Completed before device-status validation

- Extracted the existing algorithm, configuration and advice models to `features/meal_advisor/domain`.
- UI and foreground share `GetMealAdviceUseCase`; existing decision thresholds and integer tick conversion remain unchanged.
- Compatibility exports remain at the old dashboard path.
- Added a separate history eligibility use case. Its repository is resolved through `glucoseHistoryRepositoryProvider`, respecting configured local/cloud history sources. It does not directly access Drift.
- Automatic advice requires three latest distinct CGM samples, intervals of 4–6 minutes (five-minute cadence with one-minute tolerance), and latest age strictly below ten minutes. Spot/finger readings and future timestamps do not fill the series.
- History resolution/fetch has a ten-second timeout; errors or failed eligibility leave manual decisions available.
- Eligibility is checked before displaying and accepting automatic advice in UI and foreground.
- Regression tests and eligibility tests passed (131 tests at that stage).

## Completed: device status

- Preserve whether IOB and COB were supplied, instead of interpreting missing values as measured zero.
- `DeviceStatus` retains numeric fields for existing consumers and adds `hasIob` / `hasCob`. Direct constructors require numeric values and default these flags to true; ingestion mappers set them explicitly.
- Nightscout and native AAPS use the same mapper. Local AAPS serialization must preserve missingness. JSON synchronization includes the flags.
- Drift already permits NULL IOB/COB: write NULL when absent and reconstruct flags on read. No schema migration is needed.
- Shared validation requires status age strictly below six minutes, following the existing foreground expiry. Future timestamps, missing fields, non-finite numbers, negative COB and invalid BG are rejected. Negative net IOB and measured zero IOB/COB remain valid.
- Validate the original status used to compute advice as well as currently available status at acceptance; a newer status must not make expired advice input fresh.
- Manual decisions remain available. The calculator is not automatically opened and glucose is not entered in this application.

## Consequences and limitations

- UI now rejects stale status that it could previously retain indefinitely. Automatic advice can become unavailable more often; this is intentional.
- CGM freshness (<10 min) and device-status freshness (<6 min) are independent requirements.
- Status age currently uses the existing `DeviceStatus.date` (source envelope creation timestamp); the separately imported activity calculation timestamp is now persisted (see audit below), but is not yet used by the decision model or its eligibility gate.
- Existing historical zeros previously produced from absent fields cannot be recovered as missing. Older serialized data without flags also retains legacy semantics. Newly ingested data preserves missingness.
- Other screens still use numeric fallback values; this change guards Meal Advisor, not every consumer of DeviceStatus.
- CGM history currently gates eligibility; the existing calculation still uses BG/tick from DeviceStatus. Forecasts and finger readings are not substitutes for the CGM series.
- Existing integer tick parsing, TTL/TAF coefficients, large-meal behavior, and extended-carbs calculation are unchanged and still require separate work.
- Activity-related percentages, suggested percentage persistence, comparison with Bolus Wizard and historical personalization are pending.

## Verification

- 153 tests passed across Meal Advisor, dashboard, foreground meal monitoring, Nightscout device mapping, local AAPS events and local mirroring.
- Tests cover the exact six-minute boundary, future dates, absent versus zero values, negative IOB, invalid numeric values, native/JSON/Drift round trips, and expiration of original advice input even when a new status arrives.
- Legacy foreground workflow tests explicitly substitute eligibility to keep their historical time fixtures independent of data-quality tests; separate integration tests exercise the real validator.
- Generated DeviceStatus serializers were refreshed through build_runner (generated files are ignored by this repository).
- Formatting was performed after implementation. Static analysis checked after the final lint correction.


## Completed: persisted decision explanation

- Added immutable `MealAdviceTrace` with exact calculation inputs (BG, effective input trend in mg/dL/min, IOB, COB and planned macros), computed TTL/TAF, reason code and configuration snapshot.
- Reason is produced by the same branch that selects the decision; no retrospective inference from current glucose or current meal composition.
- The algorithm version remains 2 because thresholds and outputs are unchanged. Trace serialization has its own format version 1.
- Database schema 20 adds nullable `decision_context_json` to `meal_advisor_result`. `decision_reason` and `version` are now populated by the persistence path. Migration supports schema 19 and earlier supported upgrades.
- The original calculation timestamp is now persisted as `created_at`; previously this supplied timestamp was dropped by the mapper and the database default represented save time. This can change the displayed creation time for newly accepted advice. Existing timestamps are not rewritten.
- Meal details display a Polish explanation, saved inputs and model estimates. These estimates are explicitly distinguished from measurements and AAPS predictions.
- Old, unknown or malformed traces display a missing-explanation message. We do not recreate history from current data.
- Manual decisions do not receive an automatic reason or trace. The current result table records accepted advice, not every intermediate calculation or dismissed suggestion.
- No changes to dose calculation, waiting thresholds, activity percentages or personalization.
- Initial verification: 78 tests passed, including legacy algorithm cases, persistence/restore, manual trace suppression, widget rendering, backup handling and migrations from versions 17, 18 and 19. Final run: 158 tests passed across Meal Advisor, dashboard, foreground monitoring, migrations and backup.


## AAPS insulin-activity audit and import (2026-09-09)

### Findings from public AAPS source

- Reviewed the public AndroidAPS `master` source, not a captured payload from the user's phone. Actual installed-version payloads still need confirmation before relying on additional predictions.
- `LoopPlugin.buildAndStoreDeviceStatus` exports `lastRun.request.iob.json(...)` as a single object and writes its `time` as the last APS run time.
- `IobTotal.json` includes `iob`, `basaliob`, `activity`, and `time`. A separate `convertToJSONArray`/`determineBasalJson` path exists for algorithm input; this does not establish that the standard uploaded device status includes a future activity series.
- `IobTotal.combine` combines bolus and basal activity. This value does not identify the phase of an individual last bolus.
- The insulin model expresses elapsed time and curve parameters in minutes; dimensional analysis of `activityContrib` gives insulin units/minute. Activity is not directly mg/dL/min and must not simply replace the current glucose-drop term without a validated conversion.
- BG prediction arrays are conceptually different from the insulin-activity curve. No forecast is inferred from `suggested.bg`, array position or envelope age.

Sources:
- https://github.com/nightscout/AndroidAPS/blob/master/plugins/aps/src/main/kotlin/app/aaps/plugins/aps/loop/LoopPlugin.kt
- https://github.com/nightscout/AndroidAPS/blob/master/core/objects/src/main/kotlin/app/aaps/core/objects/extensions/IobTotalExtension.kt
- https://github.com/nightscout/AndroidAPS/blob/master/plugins/insulin/src/main/kotlin/app/aaps/plugins/insulin/InsulinOrefBasePlugin.kt

### Implemented

- Added `hasInsulinActivity` to preserve missing versus measured zero activity, following the existing IOB/COB approach. Existing required numeric API stays compatible.
- Added nullable `insulinActivityAt`, parsed exclusively from `openaps.iob.time`. Missing or invalid timestamps remain unknown; envelope creation time is not substituted.
- Preserve the flag and timestamp through native AAPS serialization, inter-isolate JSON synchronization and Drift round trips.
- Drift schema 21 adds nullable `device_status.insulin_activity_at`. Absent activity writes SQL NULL to the existing activity column. Existing rows are preserved with unknown model time.
- No new insulin-type configuration, future-curve reconstruction or changes to eligibility/dosing/wait decisions. These fields are prepared for subsequent analysis, not yet used by the advisor algorithm.
- Old zero activity values previously produced from missing data cannot be recovered. Old serialized objects without the new flag preserve legacy semantics.

### Verification

171 tests passed across imports, migrations, local AAPS events, Meal Advisor, dashboard and foreground monitoring. Static analysis reported no issues. Tests distinguish absent activity from measured zero, preserve model time across JSON/native/Drift round trips and verify schema 20→21 migration without fabricating historical timestamps.


## Descriptive history of total insulin activity

- Added `AttachInsulinActivityContextUseCase`, resolved through `deviceStatusHistoryRepositoryProvider`. No direct Drift reads or forced source selection.
- UI and foreground attach the optional context before displaying advice. Eligibility/freshness checks run after enrichment, so network latency cannot silently extend the original input validity.
- Query the preceding 20 minutes at the advice calculation timestamp. Exclude future calculation/envelope timestamps, absent/non-finite activity and unknown model times.
- Deduplicate by activity calculation time. Conflicting values at the same selected model time, or mixed sources in selected points, produce unknown context.
- Classification uses the latest three distinct points spanning at least eight minutes, maximum inter-point gap six minutes, and latest point age strictly below six minutes.
- Both consecutive changes must exceed 0.0001 U/min in the same direction to label rising/falling. Both within 0.0001 U/min are stable at the source's rounding precision. Mixed changes produce unknown. This is an explicit descriptive heuristic, not a clinically validated phase/prediction model.
- Persist the direction, unknown reason, exact selected model points and tolerance in the existing decision-context JSON. Optional versioned context preserves compatibility with old traces; no database migration is needed.
- History resolution/fetch has a ten-second timeout. Failure leaves an unknown context and does not itself change or block the decision. Other data-quality requirements still apply.
- Meal details display Polish labels, calculation times and U/min values, explicitly describing recent total activity rather than future activity or an individual bolus phase.
- Decision, wait, extended carbs and original calculation timestamp are preserved. Manual/empty advice bypasses enrichment.
- Verification: 147 tests passed across Meal Advisor, dashboard and foreground monitoring. Static analysis and `git diff --check` passed. Coverage includes classification, missing/stale/conflicting data, provider resolution, unchanged decision/wait/extended carbs, JSON and database persistence, and Polish detail rendering.

## Large-meal characterization and correction proposal

- Added ten synthetic characterization tests covering composition versus carbohydrate quantity, IOB interaction, high/falling BG, near-low precedence, exact TTL boundaries and decimal/malformed tick handling in the shared use case.
- Reproduced the mixed-meal switch from waiting to delayed bolus under identical glucose inputs. Confirmed that large meals do not always cause delayed bolus.
- Identified decimal tick parsing as a separate technical defect: the current integer parser substitutes zero for decimal or malformed values.
- Added `docs/meal-advisor-large-meal-review.md` with exact current outputs and a staged correction contract. Production decisions are unchanged, following the agreed review-before-recommendation-change scope.
- No clinical thresholds, insulin activity effects, extended-carbs changes or new common abstractions were introduced. Tests remain feature-specific.
- Verification: all 10 new characterization tests passed; full static analysis reported no issues and `git diff --check` passed.

## AAPS predictions as descriptive advice context

- Preserve `suggested.timestamp` and named `predBGs` through Nightscout import, native AAPS events, isolate JSON and Drift. The shared core snapshot model owns transport parsing; Meal Advisor-specific interpretation stays in its feature folder.
- Drift schema 22 adds nullable `device_status.aaps_predictions_json`. Existing rows remain unknown; no historical predictions are fabricated.
- Renamed the enrichment use case/provider to `AttachMealAdviceHistoryContextUseCase` / `attachMealAdviceHistoryContextUseCaseProvider`, because it now attaches both total insulin activity and prediction context. UI and foreground share one history-provider request and the existing ten-second timeout; freshness checks still run after enrichment.
- Select the latest status dated at or before the original advice timestamp. Do not search backward for a usable prediction if that latest record lacks one. Conflicting same-time records produce unavailable context. Snapshot model time must not be in the future or after its envelope, and both model/envelope ages must be strictly below six minutes.
- Validate recognized IOB/COB/UAM/ZT series and their finite positive mg/dL values, with 2–48 five-minute model points. Missing model timestamp, malformed payload, absent history, stale values and failures are explicitly unavailable. Prediction arrays retain the original model timestamps; envelope time never substitutes for model time.
- Compare each available series separately with TTL over the existing TAF + safety-margin horizon, starting at the advice timestamp. Use the existing low threshold, not a newly calibrated clinical threshold. Points before the advice are excluded. An observed threshold crossing can be compared even if a series ends early; no crossing in a short series means incomplete, not reassurance. This sampled comparison does not interpolate, describe the entire continuous curve, or reproduce AAPS risk aggregation.
- Save full validated series, status/model/reference times, source/id, threshold, horizon, TTL indication and per-series comparison in the versioned optional decision-context JSON. Old traces remain readable. Stale valid snapshots may be retained as evidence but are not compared. No decision algorithm version change is needed because decision rules did not change.
- Polish meal details show unavailable reasons or per-series agreement/disagreement/incomplete coverage, explaining that this is a descriptive comparison and absence of a predicted crossing is not absence of risk.
- No new dose, timing, low-glucose blocking rule or CGM fallback was introduced. Decision, wait, e-carbs and original advice timestamp are preserved; manual advice bypasses enrichment.
- Verification: 188 tests passed across Meal Advisor, dashboard, foreground, import and migrations. Coverage includes independent series, model-relative time alignment, missing/stale/future/conflicting data, truncated horizons, native/JSON/Drift round trips, schema 21→22, saved advice round trips, provider enrichment preserving behavior and Polish rendering. Full static analysis and `git diff --check` passed.

## Advice versus recorded meal history

- Added an expandable Polish comparison in advanced details of eaten meals, using the existing analysis loaded through the history providers. No additional database schema or network fetch is introduced.
- Reuse common decision labels, actual-insulin aggregation and formatting. Meal-specific window selection and widgets remain under the meals feature.
- Show saved advice/time/wait, status-recorded eating start, each valid Bolus Wizard's nullable carbs/calculated insulin/percentage, and actual positive manual-bolus records separately with offsets only when eating start is known.
- Calculator results are not counted as delivered insulin. Missing calculator fields stay unknown. Records outside the existing analysis event window, invalid entries and nonpositive/nonfinite doses are excluded.
- Show other recorded correction totals, observed CGM min/max and window, ongoing/poorly covered observation, activities and other meals in the analysis context. These are descriptive observations, not a causal assessment or automatic adherence score. No percent recommendation is fabricated when the advisor never saved one.
- Temporal proximity alone does not link a wizard/delivery to this meal. Carb-entry timestamps do not replace eating start. No recorded delivery is not proof of no delivery. Existing analysis-time fallback is explicitly identified when eating start is unknown.
- A connected Android phone was detected, but read-only `run-as` access was refused because the installed app is not debuggable. Therefore actual on-device stored advice and UI/foreground end-to-end execution were not verified. No device app installation, real meal action or treatment changes were performed.
- Verification: 327 tests passed across meals, Meal Advisor, dashboard and foreground monitoring; static analysis and `git diff --check` passed. New tests cover calculator-only history without inferred delivery, invalid/out-of-window dose filtering, and explicit unknown history/eating start. Existing small-screen/text-scale meal-review tests also pass.

## Device inspection and repeatable integration tests

- Read-only interaction on the connected Galaxy A54 confirmed basic/advanced meal history, recorded CGM, wizard/delivery separation and the new comparison section render with actual stored history. A legacy automatic result displayed the expected missing-trace message. No real advice was accepted and no treatment was sent.
- Device inspection also exposed an outstanding presentation issue: legacy stored decision statuses such as `bolused-waiting` are displayed raw in the old section and are not recognized by the new comparison's enum-name-only label lookup. This remains to fix; it does not change the persisted decision.
- Added official Flutter `integration_test` dependency and an isolated device test entry point. Android test builds have a distinct application ID/label; production ID stays unchanged. Integration targets without the isolation flag fail during Gradle configuration before installation.
- The device test app uses production calculation, enrichment, local history repository, native Drift storage and trace rendering with a synthetic dataset. It closes/reopens the SQLite connection to verify persistence. It does not initialize production services, Firebase, AAPS or real credentials. See `integration_test/README.md` for the command and coverage limits.
- This first suite is component integration on a physical device, not a claim of complete production UI/foreground end-to-end coverage.

## History wording and timestamp tolerance

- Changed Polish `Bolusy standardowe` to `Bolusy ręczne` (English: `Manual boluses`).
- Fixed rapid-rise observation being reset by nominal five-minute CGM samples arriving a few seconds apart from the exact cadence. Maximum accepted gap is now six minutes; the 2 mg/dL/min rate and minimum ten-minute sustained-rise requirement remain unchanged. Actual gaps over six minutes still break the sequence.
- Updated the displayed method description and added tests distinguishing a valid observation without rapid rise from insufficient data. This change affects retrospective display only, not Meal Advisor timing/dosing.
- Verification: both integration scenarios passed on the connected Galaxy A54 using the separate test package; 12 history/widget tests passed; final static analysis and `git diff --check` passed. The production app installed on the phone was not replaced, so the latest wording/rise-display changes still require its next build.

## Stored decision labels and production history page integration

- Fixed the presentation issue found on the physical device: both advisor details and the comparison now share `storedMealDecisionLabel`, supporting stored workflow statuses and enum names. Unknown values stay unknown; manual choices remain distinct. No persisted values or recommendation rules changed.
- Added a stable identifier to the main meal-history scroll view so device tests can distinguish it from nested chart scrollables.
- Added a device suite mounting the production `MealPageBody` with isolated database-mapped meal/advice and synthetic history. It navigates basic→advanced, expands legacy/new/manual advice and checks wizard percentage/delivery context. This extends device coverage beyond the previous trace-only harness, without starting real services or loading real credentials.
- Verification: all three production-history-page integration scenarios passed on the connected Galaxy A54. Seventeen local history/label/trace tests passed; final static analysis and `git diff --check` passed. Test execution used the isolated app package; production app data were not modified.

## Nightscout replay validation and device cleanup incident

- Added a minimal de-identified replay fixture from the previously authorized Nightscout snapshot: three CGM values and their relative millisecond offsets plus BG/IOB/COB/tick. No account/device IDs, names, credentials or absolute patient timestamps are committed; macros are explicitly synthetic.
- Five tests passed locally and on the physical Android device: fresh readings, absent readings, discontinuous readings, stale CGM and expiry while the real dialog is open. Tests use the production history eligibility provider, dialog/controller and foreground `checkAdviceEligibility`; notifications/transports are doubles, not live Android/AAPS actions. Shared calculation inputs/results are compared for valid data.
- IMPORTANT INCIDENT: after the device replay, Flutter cleanup attempted `adb uninstall pl.diabeatthis.app` rather than the isolated package. Although the log reported DELETE_FAILED_INTERNAL_ERROR, a subsequent package query (also including uninstalled packages) no longer listed the production app. The existing release APK was reinstalled successfully and both packages are present again. Preservation of the original app-private data is NOT verified. No claim of unchanged production data is valid for this run.
- Root cause found in local Flutter tools: IntegrationTestDevice captures APK identity before the new build and uses that identity at cleanup; `flutter test` defaults `--uninstall` to true. A previous normal app build occupied the shared APK output path. The Gradle isolation flag alone was insufficient.
- Added `tool/run_android_integration.sh`: prebuild the isolated target before Flutter reads APK identity, then invoke tests with `--no-uninstall`. Do not run raw device test commands after production builds. Further device tests were suspended after the incident; the new runner has shell syntax validation but was not rerun on the device during recovery.

## Removal of device integration test infrastructure

- Removed the device integration suites, their temporary database/app fixtures, README and runner at the user's request. Restored the original Android package/label configuration and dependency manifests; removed the test-only history scroll key.
- Earlier device-test entries above are historical records, including the cleanup incident; the described device testing infrastructure is no longer present.
- Kept the ordinary local widget/unit tests, including the Nightscout replay fixture and its five UI/foreground checks. Meal Advisor, history and production behavior changes are preserved.
- This cleanup changes repository files only; it does not install, uninstall or operate apps on the phone.

## Low treatment context reconstructed during meal analysis

- Added a feature repository/provider for saved, confirmed low-treatment consumption. Reuses the existing meal ingredient/history mapper for net carbohydrate quantities; AAPS suggested carbohydrates remain a separate field. Missing quantities/reasons are unknown, not zero or inferred low glucose.
- Advanced meal-advice history now reads low treatments in the two hours preceding the recorded advice timestamp. This is a descriptive display window, not a carbohydrate action duration. Related low treatments strictly after the advice reuse already loaded meal details and show timing relative to the advice.
- Per user clarification, no low-treatment details, references or availability state are added to MealAdvisorResult or its trace. No schema migration, recommendation/foreground calculation change, dose change or COB adjustment is introduced. Context is reconstructed on demand from source records and explicitly described as potentially edited or supplemented later, not a snapshot of inputs used by the algorithm.
- These local annotations include reasons and meal/activity associations absent from Nightscout history. No duplicate remote carbohydrate events are added. Unlinked later entries are not claimed to belong to the meal. Absence of a recorded consumption is not proof that none happened.
- Before-advice data load asynchronously through an auto-disposed provider; after-advice data reuse existing details. A temporary local measurement with 10,010 meals and 10 low treatments took 13 ms for the lookup in in-memory SQLite on the development computer. This is not a phone/disk/network performance guarantee; no phone interaction occurred.
- Verification: 182 local meal/low-treatment tests passed, including window boundaries, confirmed-consumption filtering, missing quantities, separate suggested/consumed carbohydrates, later source updates, history errors and before/after-advice display. Static analysis and `git diff --check` passed.

## Unified time-window context without meal linkage requirements

- Supersedes the preceding low-treatment UI scope: analysis now loads all confirmed local low treatments in the same event window as treatments and overlapping activities, regardless of related meal/activity IDs. The standalone two-hour pre-advice provider and linked-only post-advice widget were removed.
- Low treatments are transient analysis data, reused by the comparison and timeline. No low-treatment fields or IDs are persisted in MealAdvisorResult. Existing optional associations can be displayed but do not control inclusion or establish causation.
- Treatments continue to use the existing history providers (including explicit remote refresh); local activities already use overlap queries. The current event window remains one hour before the meal through its 90-minute/three-hour observation endpoint, capped at now. No additional dosing or recommendation rules are introduced.
- Verification: 182 local meal/low-treatment tests and static analysis passed. The new analysis test uses actual local history repositories and SQLite, confirming unlinked low treatments before/after the meal, exclusion outside the window, an overlapping activity starting earlier, and a treatment with no meal association. `git diff --check` passed.

## Clarification of existing low-treatment support

- Low-treatment sections and linked timeline entries predate this work. The change extends time-window context to unlinked consumption; it does not introduce low-treatment history from scratch. The user clarified that no specific missing entry was reported.
- Preserve the previous rich timeline rendering for linked entries, including entries outside the general event window; add unlinked window entries without duplicating a local record. Local IDs are used only to deduplicate existing records, not persisted in advisor results or required for temporal inclusion. The window-scoped analysis list remains bounded by eventStart/eventEnd.
- Verification: the SQLite analysis regression test passes with a linked entry outside the window, an overlapping linked/window entry rendered once with ingredient details, and an unlinked entry. Final static analysis and whitespace checks passed.

## Removal of persisted advisor context JSON

- At the user's request, removed decision_context_json from the result schema, persistence models/mappers and history UI. Schema 23 rebuilds result tables from versions 20–22 to discard the redundant JSON while preserving decisions, waits, e-carbs settings, reason/version and timestamps. Older migrations target the current schema directly.
- Removed the stored-trace section and its orphaned display widgets. Dialog and foreground no longer fetch descriptive device history merely to attach it to a saved trace. Eligibility checks and the existing decision algorithm remain unchanged.
- Source device_status insulin_activity_at and aaps_predictions_json are retained, including NULL-versus-zero handling. Internal calculation metadata and independently tested context analyzers remain available in memory, but loaded advice no longer carries a restored trace. Historical analysis uses source records rather than a stored copy of advisor inputs.
- Verification: 339 tests passed across schema migrations 17–22, result persistence, Meal Advisor, dashboard, meal history and foreground monitoring. Static analysis passed. No phone installation or live database operation was performed; migration runs when an updated app opens its database.

## Dead-code and pre-refactor regression audit

- Removed the now-unreachable history enrichment use case/provider, trace serializers, trace-only activity/prediction analyzers and their models. Removed inert test overrides. This supersedes the preceding note about retaining those analyzers for future use.
- Removed construction of duplicate input/configuration maps during advice calculation. A nullable decision reason remains directly on MealAdvice because persistence consumes it; it is restored from the existing reason column, with unknown legacy reasons handled as absent. No JSON is reconstructed.
- Preserved source AAPS prediction import, native/isolate transport, Drift persistence and migration tests, moving them out of the deleted analyzer test. Existing decision-boundary characterization remains, and TTL/TAF checks now call the real calculation methods directly.
- Compared the current calculator against the exact pre-refactor implementation from HEAD using a temporary isolated test across 3,600 combinations. Decisions, all wait bounds, extended-carb grams and schedule timing matched. Temporary reference code/test were removed after verification.
- All 668 project tests passed, including database migration/backup, source import, meal/history UI, manual/automatic advice and foreground paths. Existing linked low-treatment sections and detailed timeline entries remain; temporal context adds previously unlinked records. Static import/reference inspection found no remaining orphaned new source files from this work.

## Architecture review and asynchronous dialog fixes

- Completed the scoped architecture/regression review in `meal-advisor-architecture-review.md`.
- Added the missing mounted/request guard after reminder scheduling. Confirmation captures the original advice and status and returns false for superseded work; the dialog stays open rather than returning a misleading saved result. Tests cover delayed scheduling, disposal, skip/manual changes during validation, and the saving UI's superseded outcome.
- Migration tests now explicitly preserve nonzero e-carbs settings, reason and calculation timestamp across versions 17–22. Existing low-treatment sections/timeline, manual decisions, foreground flows and source history remain intact.
- Validation: all 674 project tests passed; static analysis and `git diff --check` passed. No phone operations occurred. The shared before/outcome context builders remain a separate next step rather than being implied by the existing history orchestrator.
