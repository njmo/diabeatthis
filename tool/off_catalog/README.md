# Open Food Facts Polish-market staging export

This disposable workspace prepares a separate ODbL dataset. It does not write to
Firebase, modify the application, or combine OFF with the USDA catalog or private
meal/health records. No API token is needed. No product images are downloaded.

Run from the repository root (Python standard library only):

```sh
sh tool/off_catalog/download.sh
python3 tool/off_catalog/prepare.py
python3 tool/off_catalog/verify.py
python3 -m unittest discover -s tool/off_catalog -p 'test_*.py'
```

The official gzipped TSV (despite the `.csv.gz` URL) is processed sequentially.
The country filter is exactly `en:poland` in `countries_tags`: sold in Poland,
not necessarily produced in Poland or named in Polish. Unknown/missing country
products are excluded. The complete world dump is downloaded once; the phone
receives none of it. The compressed source was approximately 1.53 GB when checked.

Generated files in ignored `data/poland/current/`:

- `products-pl.jsonl`: source identities, names, brands, package quantities,
  categories, raw/parsed nutrition, provenance, license and review flags.
- `catalog.sqlite`: identical records plus a local FTS5 name/brand review index
  with Polish diacritics normalization (including ł). This is a preparation
  artifact, not a database intended for mobile installation.
- `review.csv`: readable review, missing values stay blank, formula-like text
  is escaped for spreadsheet viewing.
- `manifest.json`: source URL, SHA-256, compressed bytes, UTC preparation time,
  counts, limitations and attribution. Download headers identify the upstream
  revision/date; the hash identifies the exact processed archive.

## Nutrition boundaries

This is a staging export, not a ready-to-import ingredient catalog. OFF documents
`*_100g` fields as per 100 g **or 100 ml**. The flat TSV lacks sufficient metadata
to reliably distinguish them. A Poland country tag also does not prove the label
carbohydrate convention. Both remain explicitly unknown for every staged record.
No fiber subtraction, volume-to-mass conversion or raw-to-cooked conversion is
performed. Missing fiber is not zero; malformed/negative/nonfinite values remain
null with the original string and a review flag. Products without core macros
remain searchable for review, not silently accepted as complete nutrition.

Before app/Firebase integration, hydrate selected products from full OFF records
(or process the richer JSONL dump), verify physical basis/preparation and label
convention, review source quality flags, and enforce the normal ingredient
validation boundary. Do not import these records as USDA or assign invented
USDA IDs. Stable staged IDs are `off_<code>`, preserving leading zeros.

Each complete run is published by an atomic `current` symlink switch; failed runs
leave the previous generation available. Resolve the generation once when reading
several artifacts together. Invalid Poland-market identities are counted separately
from products outside the country filter. The input hash and file identity are
checked before publication.

The local FTS index demonstrates offline server-side preparation/search. It does
not deploy a search service or change the existing barcode integration.

## Source and license

- Official export: https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz
- Export fields: https://github.com/openfoodfacts/openfoodfacts-server/blob/main/html/data-fields.txt
- Dataset guidance: https://openfoodfacts.github.io/openfoodfacts-python/usage/
- API/licensing: https://openfoodfacts.github.io/openfoodfacts-server/api/
- ODbL 1.0: https://opendatacommons.org/licenses/odbl/1-0/

Attribution: Contains information from Open Food Facts, available under the
Open Database License (ODbL) 1.0. A publicly used derivative database is subject
to ODbL attribution, share-alike and access requirements. Separating this staging
workspace documents provenance; file separation alone does not settle the legal
classification of a later integrated database. Images have separate licensing.

## Batched enrichment research

Research inputs and source-backed results live in `curation/batches/`. Use batches
of 100 records grouped by food manufacturer, with independent lightweight agents.
Use exact brand tokens: substring matching can accidentally select cosmetics
(e.g. `osm` in `cosmetics`). The source dump itself also contains non-food records;
these must never receive inferred nutrition. Existing mixed batches are retained
as an audit trail, not approved ingredient lists.

```sh
python3 tool/off_catalog/summarize_enrichment.py
python3 -m unittest discover -s tool/off_catalog -p 'test_*.py'
```

The ledger in `data/enrichment/` preserves originals and records proposed patches
only for missing fields. Exact barcode, explicit physical basis and complete core
macros are required; reported conflicts or discrepancies with existing OFF values
hold the entire patch. Missing fiber and unknown carbohydrate convention remain
unknown. `deferred` means not researched, never “not found”. Counts distinguish
assigned records from researched records. A source-backed proposal is not import
approval. No research or summary command writes to Firebase.

## Whole manufacturer catalogs (barcode optional)

```sh
python3 tool/off_catalog/bulk_catalog.py
python3 tool/off_catalog/match_bulk_catalogs.py
```

The current adapters cover the entire published product sitemap of **Mlekovita**
and **Piątnica**, not one web search per missing OFF item. Independent sites can
be downloaded concurrently, while each host is paced and its robots rules are
respected. Cached responses have source URLs, acquisition timestamps and SHA-256
checksums. Rerunning resumes missing downloads and reparses cached pages. Use
`--refresh` to deliberately fetch a new snapshot. `--limit` is diagnostic only:
the resulting incomplete catalog cannot be used to establish unique matches.
Transient HTTP 429/503 stops the source rather than continuing to hammer it.

Each source produces `data/bulk/<manufacturer>/catalog.jsonl` and a manifest.
Source records without a barcode are retained with an independent URL-derived
ID; no artificial barcode is created. Other producers need a configured and
tested adapter in `bulk_catalog.py` (public catalog format varies by site).
Unsupported producers are counted separately, not reported as researched.

Matching runs locally against the complete source snapshots and produces
`data/bulk_matches/proposals.jsonl`, `exceptions.jsonl`, a manifest, and exception
batches of 100. It tries matching manufacturer + barcode first, then exact
normalized manufacturer/name/variant with compatible package quantities. Known
conflicting codes, flavors, fat percentages, lactose claims, multipacks and
ambiguous matches require review. Similarity ranking only proposes a shortlist
for the exception queue; it never imports nutrition automatically.

A nutrition proposal is a **complete, atomic manufacturer profile** with its own
100 g or 100 ml basis. It never combines newly found values with old OFF nutrients
of unknown physical basis. Missing fiber remains null even when the old record
had a fiber value. Existing conflicting facts are held for review. The original
OFF archive and SQLite catalog remain unchanged. Carbohydrate convention and
publication rights still require review before application/Firebase integration.

Only exception batches go to lightweight agents. Agents choose a source catalog
identity (or leave it unresolved), citing the local catalog's URL and preserving
variant/package distinctions. They must not estimate nutrition or invent codes.
Example result: `curation/bulk_piatnica_resolutions.json`.

These commands contain **no Firebase write operation and no AI API call**.
The source catalogs are separate manufacturer evidence, not automatically relicensed
as OFF data and not ready for public redistribution just because a site is public.

## Named-only working catalog and complete required-macro audit

```sh
python3 tool/off_catalog/clean_working_catalog.py
python3 tool/off_catalog/verify.py
python3 tool/off_catalog/match_global_off.py
python3 tool/off_catalog/compile_final_audit.py
```

The cleanup publishes a new working generation without blank names, rebuilding
SQLite, FTS, JSONL and CSV consistently. The downloaded world archive and prior
source generation remain available for provenance. Required fields are **carbs,
fat, protein**. Missing fiber or energy is optional and does not invalidate core
macro completeness; neither is replaced with zero. Original flags remain under
`source_review_flags`; `macro_audit` records the exact missing-field combination,
range-review cases and non-food/identity routing for every named record.

`match_global_off.py` scans the entire already downloaded world export once,
matching exact names with maker evidence where available. It keeps different
macro profiles separate and never averages them. A global match is an identity,
physical-basis and convention review candidate, not an approved product. This
avoids one web query per otherwise anonymous row.

`data/final_audit/report.json` reconciles all named records. Other outputs:

- `all_named_records.jsonl`: every named record, its assessment and source candidates.
- `core_complete_for_review.jsonl`: reported complete core macros or a non-conflicting
  complete source profile; this is not publication approval.
- `remaining_gaps.csv`: required-macro/identity/range cases, excluding non-food rows.
- `manufacturer_profiles.jsonl`: complete required-macro profiles independently
  downloaded from producers, including products without barcodes.
- `partial_*_result.json`: evidence-based exception research for all 464 records
  originally missing one or two core fields. Other records missing all three need
  a whole nutrition profile, not a fiber backfill.

The available additional adapters are Sante and OSM Łowicz. Sante currently has
unavailable legacy URLs in its published map; its incomplete snapshot cannot be
used for automatic unique-name matching. Individually retrieved source profiles
remain reviewable. To match the complete snapshots explicitly:

```sh
python3 tool/off_catalog/match_bulk_catalogs.py --sources \
  tool/off_catalog/data/bulk/mlekovita \
  tool/off_catalog/data/bulk/piatnica \
  tool/off_catalog/data/bulk/lowicz
```

Unresolved source/identity cases remain unresolved; no script fills them with
estimated values or claims that all missing products have been repaired.

## Sensible zero completion

```sh
python3 tool/off_catalog/normalize_type_zeros.py
python3 tool/off_catalog/verify.py
python3 tool/off_catalog/compile_final_audit.py
```

This user-authorized pass fills missing core fields with explicit zeros when
supported by a source-reported zero or a narrowly matched commodity rule: pure
plant oils have zero carbohydrate/protein; plain sugar has zero fat/protein;
plain water and salt have zero core macros. It processes partial records only,
never inventing an oil's fat amount or a sugar's missing carbohydrates. Flavored
mixtures, fish in oil, olives, butter, vitamin waters and sugar-free claims are
not classified as pure commodities. Reported nonzero source evidence blocks the
generic zero rule for that field.

Every filled field has `nutrition_imputations` provenance distinguishing
`source_reported_zero` from `type_based_zero_imputation`. The source snapshot
`nutrition_as_exported` remains intact; `nutrition_working` is a published view.
Use `common.nutrition_facts.working_nutrition` for working reads: later known
source values always win over an older inference or cached working value.

Contradictory existing values and suspicious bases (e.g. oil with 10 g fat and
90 kcal in a nominal per-100 export) keep their reported values and receive review
flags. Such rows are not silently treated as unproblematic products. Zeros never
change the EU/US carbohydrate convention, physical basis, portions or application
history. Missing fiber remains optional and is not filled by this pass.

The cumulative audit is `data/poland/current/type_zero_report.json`; each working
record also carries its own derivations. Reruns are idempotent and report both
the current-run delta and cumulative changes. Nothing is uploaded to Firebase.
