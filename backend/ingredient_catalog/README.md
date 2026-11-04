# Ingredient catalog callables

Deployed on 2026-11-03 to Firebase project `diabeatthis-e634c`, region `europe-west1`, using Node.js 22 and Cloud Functions generation 2:

- `https://europe-west1-diabeatthis-e634c.cloudfunctions.net/searchIngredients`
- `https://europe-west1-diabeatthis-e634c.cloudfunctions.net/getCatalogIngredient`

Both are callable endpoints and require a valid `X-Firebase-AppCheck` token. Requests use the callable `{"data": ...}` envelope; successful responses use `{"result": ...}`. They read the published catalog/index without writing catalog data. Firebase Authentication is not required. App Check enforcement remains enabled.

The active release `pl-en-v1-6c538dbe46cebf601538` contains 2203 foods in 15 checksum-verified chunks. Live verification returned Polish cooked-rice search results and matching ingredient facts per 100 g; both endpoints rejected unattested requests with HTTP 401. The user also confirmed results on the release application. A temporary probe registration was deleted after the check; no secret or token was logged or persisted, and all six previous debug registrations remained.

Android debug installations need their own registered App Check debug token. Release installations use the configured Play Integrity provider. A successful server probe does not register another installation automatically.

Run local backend tests:

```sh
node --test backend/ingredient_catalog/test/*.test.cjs
```

Deploy only these functions from the repository root:

```sh
firebase deploy --project diabeatthis-e634c --config backend/ingredient_catalog/firebase.json --only functions:ingredient-catalog:searchIngredients,functions:ingredient-catalog:getCatalogIngredient
```

The deployment enabled the required Functions, Build, Run and Eventarc services. Billing was already enabled. Both functions use zero minimum and four maximum instances. The new `europe-west1/gcf-artifacts` repository has a Firebase-supported 7-day image cleanup policy; no unrelated repositories or catalog documents were changed.

See `docs/ingredient-catalog-architecture.md` for identity, translations, publication, source snapshots and verification details.

### Source language

New index entries retain `name` and `languageCode` (`pl` or `en`). Missing
`languageCode` means English only for compatibility with existing USDA records.
Translation rows carry `ingredientId`, `languageCode` (legacy default: `pl`),
`sourceName`, `name`, optional `aliases`/`details`, and a reviewed or machine-translated
status. A translation is never required for a source name to be searchable.
Search and detail responses share the same display selection: requested translation,
then the original name with its actual language. Nutrition and source identity do not
change with the display language. Missing English translations remain null rather
than labelling a Polish name as English. Existing version-one search releases remain
readable. The local mirror snapshot retains the original name separately.

This change does not publish data or enable manufacturer/OFF ingestion. Identity
validation still permits only the deployed USDA namespace; index building rejects
other identities so an unpublished namespace cannot break search in current clients.
Before importing additional sources, extend identity validation consistently in the
backend, app repository and mirror store, and verify the importer nutrition contract.
