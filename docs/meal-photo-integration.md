# Meal photo integration

## Recognition and review

The shared configured photo AI client makes one structured recognition request.
It returns both a whole-plate reference and itemized component proposals.
A plate photo is required; the description and menu image are optional context.
A referenced menu position must be unambiguous before estimation can continue.
Clarification questions and displayed names use the application's language;
USDA-style descriptions and fallback search queries remain English.
An explicitly configured country of residence is a weak regional hint, not a
confirmed restaurant location. Visible evidence and user descriptions take priority.

The default preview represents the whole plate. Catalog lookup starts only when
the user chooses to divide it into ingredients; it does not call the model again.
The review has three pinned stages: Context, Ingredients and portions, and Summary.
Each portion can be accepted and collapsed while the next card is revealed.
Users can replace products, accept or edit reference nutrition, add missing
components, remove components with undo, and rename the meal before saving.
Reference and catalog choices are retained when switching sources.

Timing defaults to now. Editing the time to a future date changes the final
action from starting the meal to saving it. Starting enters the existing guarded
meal-start flow without repeating the initial eat/skip choice. Post-save actions
never repeat persistence. Canceled or outdated asynchronous results cannot replace
a newer proposal, and repeated save taps share the same pending operation.

## Ingredients, persistence and provenance

Reference nutrition describes the entire visible portion. Positive confirmed
physical grams normalize it to an ordinary gram-based ingredient at storage time.
Fiber and the EU/US carbohydrate convention remain available. An exact existing
photo reference is reused only when normalized name, scope, convention and per-100g
macros agree. A same-name product can instead be selected explicitly or the user
can deliberately create a different reference version.

Catalog products have stable composite identities. Mirroring occurs only for
selected products. An existing mirror keeps its reviewed revision and canonical
source snapshot; newer search results hydrate that existing revision before
review instead of silently refreshing historical facts. Editable local copies
retain independent source provenance.

The “New” chip previews the same reuse checks used by saving, including whether a
remote product already has a local mirror. It appears during portion review and
in the final summary when a new database ingredient will be created.

PreparedMealPhotoSaver materializes ingredients and calls the normal meal writer
inside one transaction. Failure rolls back references, mirrors, provenance and
meal rows together. Optional background icon classification is disabled within
that transaction.

Schema 46 adds ingredient_origin without changing existing ingredient IDs or
meal/portion foreign keys. Schema 47 adds a nullable per-meal ingredient nutrition
confidence override. Photo reviews store the reviewed confidence separately from
canonical product confidence, including an explicit zero. Legacy null values use
the existing canonical/historical fallback. Reloading, copied-row review, planned
and consumed snapshots, and backup/restore preserve this distinction. Replacing
a product clears an unrelated override.

## Nutrition and display boundaries

EU carbohydrate values exclude fiber. US values include fiber, so fiber may equal
but cannot exceed US total carbohydrate. Subtraction happens once. EU carbohydrate
and fiber values are independent.

The shared macro presentation labels net carbohydrates explicitly and displays
fiber separately. Its four-color bar uses gram shares, not calorie percentages.
The carbs/eCarbs summary uses the same rounding and protein/fat conversion as meal
start. The conversion threshold is evaluated on raw totals before presentation
rounding, so review, saving and later completion agree near the boundary.

The shared catalog search covers local ingredients and the deployed Firebase
callable catalog endpoints. Local search and reference review remain available
when catalog requests fail. Missing source facts remain missing rather than being
invented to force a match.

## Diagnostics and regression coverage

Raw response diagnostics are debug-only. Release/profile builds do not print
model responses or remote error bodies. Bounded stage metadata and allowlisted
failure categories remain available. The controller can retain the exact response
in memory for diagnostics without adding JSON actions to the normal review UI.

Regression coverage includes proposal parsing, optional context and menu
clarification, app language and country context, immutable catalog revisions,
reference reuse, confidence overrides through actual save/reload/snapshots/backup,
legacy migration, copied-product replacement, EU/US carbohydrate boundaries,
raw WBT thresholds, cancellation and stale results, rollback, duplicate saves,
pinned steps, automatic portion scrolling and system-navigation spacing.
