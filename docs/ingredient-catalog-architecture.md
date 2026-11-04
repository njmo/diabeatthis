# Shared ingredient catalog translations and search

The shared catalog keeps nutrition under stable USDA identities. Localized names and search aliases belong to those identities. A Firebase callable searches a server-side index and returns at most 20 results; the phone never synchronizes the catalog to make search work. Local products remain searchable immediately in Drift.

## Implementation state

The canonical catalog contains 2203 foods. All have a Polish translation document in Firebase: 1802 have `machine_translated` status and 401 have `needs_review` status. A published search release contains all 2203 English identities and the 1802 eligible Polish translations. Nutrition was verified unchanged after publication.

The App Check-protected `searchIngredients` and `getCatalogIngredient` callables were deployed to `diabeatthis-e634c` in `europe-west1` on 2026-11-03. Live verification covered a Polish search, canonical ingredient retrieval and rejection of unattested requests. The active release `pl-en-v1-6c538dbe46cebf601538` contains 2203 records in 15 checksum-verified chunks. Flutter unified search and selected-food persistence are implemented under `lib/common/ingredient_catalog`; deployment does not download the catalog to the device.

## Data ownership

| Data | Location | Owner |
| --- | --- | --- |
| Canonical English food and nutrition per 100 g | `common/ingredients/items/{sourceId}` | Catalog administrator |
| Polish label, details and aliases | `common/ingredients/items/{sourceId}/translations/pl` | Catalog administrator |
| Active search release pointer | `common/ingredient_search` | Catalog publisher |
| Immutable search release metadata | `common/ingredient_search/releases/{releaseId}` | Catalog publisher |
| Search index chunks | `common/ingredient_search/releases/{releaseId}/chunks/{chunkId}` | Catalog publisher |
| Personal products, portions and selected-food facts | Local Drift database | User |

Firestore paths alternate collections and documents. `common/ingredients` is a namespace document path, and `items` is its food collection. A namespace document need not exist to contain the subcollection.

Translation records contain no nutrition. Changing a label never changes carbohydrates, fiber, calories, preparation facts, the USDA identifier, or a saved meal.

## Ingredient identity

Use a composite identity at the search boundary:

```json
{ "source": "firebase", "sourceId": "usda_170440" }
```

A local identity uses `source: local` and the local numeric ID represented as a string at this boundary. Display language is not part of identity. Do not deduplicate by display name: two similarly named foods may have different preparation or nutrition.

`Ingredient.id` remains a numeric local ID. Migration 46 adds the separate `ingredient_origin` table, preserving existing ingredient constructors and all meal, template and portion foreign keys. Existing and newly created ingredients receive local origin rows. Selected catalog snapshots carry a unique `(source, source_id)` identity, source revision and original source metadata; selection atomically reuses that identity without refreshing its frozen facts.

Saving a selected remote food is different from downloading the whole catalog. Persist the selected ingredient's facts and source identity for meal calculations and offline history. User-created portions remain local. A user-created independent copy becomes a local identity and retains an immutable copy of the exact original source snapshot in `copied_from_json`. Catalog mirrors are read-only; editing uses an explicit independent copy. Neither path overwrites the shared product or merges by display name.

## Translation contract

```json
{
  "ingredientId": "usda_170440",
  "languageCode": "pl",
  "name": "Ziemniaki gotowane bez skórki, bez soli",
  "details": "Jadalny miąższ, gotowany bez dodatku soli.",
  "aliases": ["ziemniaki gotowane", "kartofle gotowane"],
  "status": "machine_translated",
  "reviewNotes": [],
  "translationVersion": 1,
  "sourceName": "Potatoes, boiled, cooked without skin, flesh, without salt",
  "sourceTextSha256": "sha256 of the exact source name",
  "translationSource": {
    "type": "model",
    "model": "model identifier used for this release"
  }
}
```

`machine_translated` records passed structural and terminology checks but do not claim human approval. `needs_review` records contain an uncertain translation or a failed semantic check. A future `reviewed` state can record an explicit review with reviewer provenance.

The initial index uses `machine_translated` and `reviewed` Polish labels. For `needs_review`, it falls back to the canonical English name and returns `displayLanguageCode: en`. Draft translations still exist beside their ingredient IDs for correction. They are not published as confident Polish labels.

Preserve distinctions across the concise name and details: cooked versus raw, preparation method, skin, lean meat versus meat with fat, bones, salt, enrichment, drained state, and fat content. US meat grades remain USDA Choice or USDA Select. US anatomical cut names without a reliable Polish equivalent retain their English source and need review.

Aliases provide useful food-family names, inflections and synonyms. They must not turn cooked rice into raw rice, a specific meat cut into a different one, or soy flour into wheat flour. Search normalization handles accents; duplicating every alias without diacritics is unnecessary.

Do not store the catalog's translated names in Flutter ARB files. ARB remains the source of UI copy such as “My products”, “Shared catalog”, errors and source markers. Catalog labels are versioned data.

## Publication sequence

1. Verify the audited English export against the live canonical collection.
2. Generate translation batches with exact input IDs and source text hashes.
3. Validate coverage, names, aliases, preparation terms and numeric qualifiers. Review representative records and flag uncertain translations.
4. Create translation documents without overwriting existing edits. Read back and compare every written field.
5. Build index entries from canonical foods and eligible translations. Index entries contain labels, aliases, source identity and icons, not duplicated nutrition.
6. Hash the index and write immutable chunks plus release metadata. Read back and verify them.
7. Switch `common/ingredient_search.activeRelease` using the previous document update time as a precondition. The active pointer changes only after a complete release exists.
8. Verify canonical nutrition again. Translation publication must not change it.

An interrupted publication leaves the previous active release usable. Rerunning can reuse identical existing documents. Different existing translations cause a conflict instead of being overwritten. Deliberate translation updates need a separate versioned update operation with read-derived preconditions.

An English source-name change invalidates its old translation. A nutrition change requires publishing a new catalog revision and deliberate handling of selected local snapshots; it must not retroactively alter historical meal facts.

## Search request and response

The deployed callable `searchIngredients`, in `europe-west1`, accepts:

```json
{
  "query": "ryz braz",
  "languageCode": "pl",
  "limit": 20,
  "cursor": null
}
```

The response contains bounded display records:

```json
{
  "releaseId": "pl-en-v1-releasehash",
  "items": [
    {
      "identity": { "source": "firebase", "sourceId": "usda_169704" },
      "name": "Ryż brązowy, długoziarnisty, gotowany",
      "details": "Wariant przygotowania z tłumaczenia",
      "displayLanguageCode": "pl",
      "translationStatus": "machine_translated",
      "englishName": "Original USDA name",
      "iconId": "rice",
      "iconAssetPath": "assets/icons/food/rice.png",
      "group": "cooked_grain_or_pasta"
    }
  ],
  "nextCursor": null
}
```

Normalization lowercases text, removes diacritics, explicitly converts Polish `ł` to `l`, and splits punctuation and whitespace. Matching requires every query word, independently of word order. Word prefixes support incomplete input; a small explicit set of food and preparation stems handles common Polish inflections. This is not a general Polish morphological analyzer or typo-correction engine.

Exact names and exact word matches rank above prefix and detail matches. Aliases and English fallback remain searchable. Ties use deterministic ordering. A cursor is bound to the query, language and release, so it cannot silently continue a different search or mix two catalog releases.

Empty and one-character queries return no remote results. Input is limited to 120 characters and eight distinct search terms. The server enforces a maximum of 20 results regardless of the client's request.

## Server caching

On first use, a function instance reads the active pointer, release metadata and index chunks. It verifies the record count and checksum and prepares searchable fields in memory. Concurrent cold requests share one load.

Warm requests search the in-memory index. Each instance checks the release pointer at most once per 60 seconds. A new active release causes a complete validated replacement. A corrupt or unavailable release produces an error, not a successful empty result. Instances do not share memory, so each new instance can perform its own initial reads.

For the current catalog size, a linear scan of prepared server-side entries is a simple starting point. If the catalog grows materially or typo tolerance becomes necessary, replace this implementation behind the same callable contract with a dedicated search service. A bounded query over an arbitrarily truncated Firestore candidate set must not be presented as exhaustive multiword search.

## Loading a selected product

The prepared callable `getCatalogIngredient` accepts `sourceId` and `languageCode`. It reads the canonical food and the requested translation. A missing, stale or uncertain translation falls back to English. Nutrition comes from the canonical ingredient, never from the search index or translation document.

The app validates the selected record, stores only the ingredient it actually uses, and preserves `nutritionBasisGrams: 100`, `carbsLabelMode: non_eu`, and separately supplied fiber. Its calculation code subtracts fiber once when deriving available carbohydrates. This ordinary catalog product has `isReference: false`; it does not use the app's special reference-portion arithmetic.

## Combining local and remote search in Flutter

Introduce a coordinator in `lib/common/ingredient_catalog` and reuse it in both ingredient pickers and LLM assignment screens. The existing local search providers remain the source of immediate local results.

For each query revision, the coordinator:

1. Starts normalized local Drift search immediately.
2. Debounces remote search by approximately 300 ms and starts it for at least two characters.
3. Renders local results without waiting for the network. Remote loading and errors belong only to the shared-catalog section.
4. Ignores responses from an older query revision or a previous language.
5. Shows “My products” and “Shared catalog” in one picker, with a cloud marker for remote results.
6. Suppresses a remote identity already represented by a local selected-food snapshot. Similar names and independent personal copies remain separate.
7. Requests the next remote page only when needed. An expired release cursor resets the remote page without clearing local results or existing selections.

Use a common normalization specification for local search; SQLite's existing `LIKE` and lowercase conversion alone do not supply the same Polish accent and inflection handling. Add normalized local search fields or a suitable local index in a separate migration. Preserve original personal product and brand names.

Offline mode retains local search and previously selected products. It should state that shared-catalog search is unavailable rather than report “No ingredients found” for a network failure. A small bounded cache of recent result pages is optional; no whole-catalog download is part of this design.

## App state and contracts

Suggested reusable types are `IngredientIdentity`, `IngredientSearchItem`, `IngredientDisplayName`, `CatalogSearchPage`, and `IngredientSearchState`. Keep local results, remote results, remote loading/error, the current query revision, and remote cursor separate. Resolve a search item into the existing persisted ingredient only after the user selects it.

The LLM receives candidate source IDs and may propose them without translating identity. Replacing an LLM component with a chosen catalog or personal product preserves estimated grams. A component reference remains a portion estimate, not an ordinary per-100g product. Whole-meal reference and itemized proposals remain alternatives.

## Access and deployment

The callable definitions enforce Firebase App Check. They do not require a new user login because the current app has no shared-catalog Firebase Authentication flow. Administrative publication uses the existing CLI account; credentials never belong in Flutter or in search requests.

Direct Firestore client rules can remain closed when reads go through these callables. The service account needs read access to the catalog and index. Ordinary clients must not write canonical foods, translations, releases, or the active pointer. App Check is an application-integrity control, not per-user rate limiting; introduce per-user quotas if authentication is added or abuse requires it.

The deployed function source is under `backend/ingredient_catalog`; deployment is separate from publishing translations and the index. Deployment needs an enabled Firebase Functions service, the required billing plan and an appropriate deployment account. Configuration sets zero minimum instances and bounded maximum instances.

From the repository root, the scoped deployment command is:

```sh
firebase deploy --project diabeatthis-e634c --config backend/ingredient_catalog/firebase.json --only functions:ingredient-catalog:searchIngredients,functions:ingredient-catalog:getCatalogIngredient
```

The Flutter callable client, source mapping, picker coordinator, localization labels and selected-food migration are implemented. Existing tests retain their scenario data and expectations; authorized updates mock the new search and origin boundaries.

## Verification

Tests cover Polish normalization, reordered multiword queries, common inflections, prefix matching, language fallback, bounded pagination, cursor binding, stale translations, concurrent cache loads, cache refresh and corrupt release rejection. Publication reads every translation and index chunk back and verifies that canonical nutrition is unchanged.

Live verification on 2026-11-03 returned HTTP 200 for Polish `ryz` search and retrieval of `usda_168897` (Ryż dziki, gotowany), with `nutritionBasisGrams: 100`, `carbsLabelMode: non_eu`, carbohydrates 21.3 g and fiber 1.8 g. Both endpoints returned HTTP 401 `UNAUTHENTICATED` without App Check. The user also confirmed shared-catalog results on the actual release installation.

The automated live probe used a temporary debug registration and a cryptographically random UUID4, as required by the App Check API. The secret and resulting attestation remained only in process memory. The registration was removed in `finally`, deletion was verified, and the original six debug registrations remained. No IAM roles, service-account keys, catalog records or enforcement settings were changed. An attempted existing-service-account signing probe was denied and no signing permission was added.

Android debug installations require their own registered debug token. Release installations use the already configured Play Integrity provider. Automated regressions cover offline local results, late responses, source deduplication, immutable selected facts and backup compatibility.

The Firebase CLI created both functions successfully but initially exited with a warning because the new `europe-west1/gcf-artifacts` repository lacked an image cleanup policy. A Firebase-supported 7-day policy was then applied successfully to that repository only. Both functions were independently verified as `ACTIVE`.

## References

- [Firebase callable functions](https://firebase.google.com/docs/functions/callable)
- [App Check enforcement for functions](https://firebase.google.com/docs/app-check/cloud-functions)
- [Firestore query operators and limitations](https://firebase.google.com/docs/firestore/query-data/queries)
- [Firestore REST atomic commits](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/commit)
