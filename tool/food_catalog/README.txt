Disposable basic ingredient catalog preparation
=============================================

This directory is a one-off data preparation workspace. Nothing here changes
the Flutter app, its database schema, its dependencies, or existing tests.
Preparation, audit and check scripts are read-only with respect to Firebase.
import_firebase.cjs upload performs the explicitly requested create-only import.

Run from the repository root with Python 3.11+:

  python3 tool/food_catalog/prepare.py --download
  python3 tool/food_catalog/audit.py
  python3 -m unittest discover -s tool/food_catalog -p 'test_*.py'
  python3 tool/food_catalog/check_firebase.py
  node tool/food_catalog/import_firebase.cjs dry-run
  node tool/food_catalog/import_firebase.cjs check
  node tool/food_catalog/import_firebase.cjs upload
  node tool/food_catalog/import_firebase.cjs verify

Preparation and auditing use only Python's standard library. The Firebase check
uses the installed Firebase CLI and its existing login, through its read-only
MCP methods. No account keys or access tokens are printed or saved. A temporary
Firebase project context lives inside the ignored data/ directory, leaving the
app's Firebase configuration unchanged.

Outputs in data/ (not Flutter assets, not downloaded to users' phones):

  catalog.sqlite       Selected basic foods, their review status, original JSON.
  catalog.jsonl        All selected foods, including those held for review.
  ready.jsonl          Only foods passing the automated nutrition checks.
  review.html          Human-readable table of every selected food and icon ID.
  review.csv           Names, macros, review flags and proposed icon mappings.
  excluded.json        Foods intentionally excluded from the basic catalog.
  manifest.json        Source releases, counts and file checksums.
  firebase-check.json  Read-only inspection of the real cloud database.

Scope agreed for this preparation:

- English canonical USDA names and stable USDA document identifiers.
- Per-100g values only. No household portions or invented serving weights.
- US total carbohydrates and fiber are preserved independently.
- carbsLabelMode is non_eu; carbohydrateDefinition is total_including_fiber.
  Consumers subtract fiber once. EU data would use eu and no further subtraction.
- Basic plate components: cooked white/brown rice, cooked pasta, cooked potatoes
  and sweet potatoes, plain vegetables, fruit, cooked meat/fish, legumes, plain
  dairy/bread, nuts, oils, flour and plain breadcrumbs. Raw fruit and salad
  vegetables are retained. Flour and breadcrumbs are intentional dry ingredient
  exceptions; uncooked rice and pasta are still excluded.
- No uncooked rice, dry/raw pasta, raw cooking meats, ready meals, ravioli,
  desserts, jams, cookies, industrial oils, infant formula, human milk,
  mushrooms/fungi, algae, spices, or unusual powders/extracts. There is no global
  5g macronutrient threshold: ordinary low-macro vegetables remain included.
- SR Legacy supplies the selected foods. FNDDS is downloaded and examined but
  deliberately excluded because this scope does not include prepared dishes.
- Source names are never relabeled as supposed equivalent Polish dishes.
  A beef patty is not automatically a Polish cutlet with breadcrumbs.

quality_issues screens missing macros, out-of-range values, fiber consistency,
mass consistency, declared alcohol and unusually different source energy.
Energy screening uses a rough calculation, not a replacement for source kcal.
Missing fiber stays null; it is never filled with zero. Review flags do not
establish that the USDA source is wrong. Only ready.jsonl is a proposed upload
set, and it still requires review before import. The source's nutrition quality
is not represented by an invented numerical confidence score.

The audit verifies export checksums, SQLite integrity, selected identities and
names, source nutrient equality, carbohydrate mode, lack of portions, review
statuses, and the existence of every referenced icon in the app's asset catalog.

Icons are selected from the app's FoodIconAssets and WickedFoodIconAssets maps.
Each record stores iconId, iconAssetPath and iconMatchMethod (name_match,
category_match or fallback). These are proposed illustrations, not nutritional
recognition confidence. Generic fallback remains explicit. No new image files
are generated or uploaded.

Firebase destination planned: common/ingredients/items/{usda_<fdcId>}
Firestore alternates collections and documents: common/ingredients is a
namespace document; items is the actual collection of ingredient documents.
The requested ingredient documents have now been imported into this collection.
No namespace metadata document, rules or indexes were deployed. Every field of
every imported document was read back and compared with the audited export.
See data/firebase-import-report.json for the import checksum and result.

Firebase inspection found the default STANDARD Firestore database in eur3.
The target was empty before import. Its client rules currently deny all
reads/writes. Future application access requires deliberately scoped read rules;
the shared catalog must not be writable by ordinary users. CLI administrative
read access does not prove client access or authorization to write documents.

Future app behavior (recorded only, not implemented):

- Query catalog remotely in bounded result pages instead of syncing it all.
- Show a cloud marker when an ingredient comes from the shared catalog.
- Let the user replace an LLM-proposed ingredient while retaining estimated grams.
- Ground LLM matches in actual catalog IDs/names, not invented USDA names.
- Accept meal photos together with optional text and a menu photo.
- For an item that cannot be reasonably decomposed or matched (for example a
  particular minced cutlet), propose a user-reviewed reference ingredient with
  estimated nutrition and low confidence rather than fabricate a catalog match.
- The app's current isReference type has special amount/fiber behavior. Ordinary
  catalog foods use isReference=false. The future estimated-reference flow must
  explicitly handle those semantics before it is connected to meal arithmetic.
- Keep user overrides separate from the shared source; selected-food identity,
  local IDs and historical nutrition require a separate app integration change.
- Current non-EU draft validation rejects zero net carbohydrate. This must be
  reviewed during future integration so ordinary meat, fish and oils with zero
  carbohydrate can be selected without inventing positive carb/fiber values.

Sources:
https://fdc.nal.usda.gov/download-datasets/
https://fdc.nal.usda.gov/api-guide/ (public-domain/CC0 data; retain USDA attribution)

Import implementation: uses the installed Firebase CLI authentication modules
and the official Firestore REST commit/list APIs. Creates are conditional on
nonexistence; existing records must match exactly or the import stops without
overwriting them. Re-runs can resume matching partial imports. The verifier
compares all catalog fields, including names, macros, source IDs, US carbohydrate
mode and icon references. The importer never deploys access rules.

Polish translations and search architecture
=========================================

Polish translation documents have been published beside all 2,203 ingredients.
1,802 are machine_translated; 401 need review and use English in the active
search release. These statuses do not claim human approval. No nutrition fields
were changed. Every translation and index chunk was read back and compared.

The active bilingual search release is stored under common/ingredient_search,
with immutable release metadata and 15 chunks. These chunks are server inputs,
not a whole-catalog download for the Flutter app.

Callable source: backend/ingredient_catalog. Deployed 2026-11-03 to
project diabeatthis-e634c, europe-west1: searchIngredients and getCatalogIngredient.
Live Polish search and ingredient retrieval passed with valid App Check;
unattested requests to both functions returned HTTP 401. The temporary probe
registration was deleted and the original six debug registrations were retained.
The user confirmed shared-catalog results on the actual release application.
Active index: pl-en-v1-6c538dbe46cebf601538, 2203 foods, 15 verified chunks.
Build images in the new europe-west1/gcf-artifacts repository have a 7-day
cleanup policy. No catalog records or access-enforcement settings were changed.
Architecture: docs/ingredient-catalog-architecture.md.
Reports: data/polish-publish-report.json and data/polish-search-verification.json.

Scripts:
  node tool/food_catalog/translate_polish.cjs
  node tool/food_catalog/validate_translations.cjs
  node tool/food_catalog/publish_polish.cjs
  node tool/food_catalog/publish_polish.cjs --execute
  node tool/food_catalog/verify_polish_search.cjs

translate_polish.cjs uses the project's available Vertex AI model, in cached
batches. validate_translations.cjs checks IDs, original names, translation text,
preparation and numeric qualifiers. The publisher is create-only for translations
and immutable release documents, preserves existing edits, and switches the
active pointer using a read-derived update-time precondition only after checks.
Do not rerun generation to overwrite reviewed translations. A deliberate update
requires a separate reviewed version operation.
