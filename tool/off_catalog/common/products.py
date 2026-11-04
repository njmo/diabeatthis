"""Preserve OFF facts without inferring label conventions or physical units."""

import math
import re
import unicodedata

NUTRIENTS = {
    "carbs": "carbohydrates_100g",
    "fiber": "fiber_100g",
    "fat": "fat_100g",
    "protein": "proteins_100g",
    "energy_kcal": "energy-kcal_100g",
}


def tags(value):
    return sorted({part.strip() for part in (value or "").split(",") if part.strip()})


def search_text(value):
    value = value.casefold().replace("ł", "l")
    return "".join(c for c in unicodedata.normalize("NFKD", value)
                   if not unicodedata.combining(c))


def number(value):
    if not value or not re.fullmatch(r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?", value.strip()):
        return None
    parsed = float(value)
    return parsed if math.isfinite(parsed) and parsed >= 0 else None


def product_from_row(row):
    """Return a Poland-market staging record, never an approved nutrition record."""
    countries = tags(row.get("countries_tags"))
    if "en:poland" not in countries:
        return None
    code = (row.get("code") or "").strip()
    if not re.fullmatch(r"[0-9]{1,32}", code):
        return None
    name = (row.get("product_name") or row.get("generic_name") or "").strip()
    raw = {field: row.get(field, "") for field in NUTRIENTS.values()}
    nutrition = {key: number(raw[field]) for key, field in NUTRIENTS.items()}
    flags = ["nutrition_basis_unresolved", "carbohydrate_convention_unresolved"]
    if not name:
        flags.append("missing_name")
    for key, field in NUTRIENTS.items():
        if nutrition[key] is None:
            flags.append(("missing_" if not raw[field].strip() else "invalid_") + key)
        elif key != "energy_kcal" and nutrition[key] > 100:
            flags.append("out_of_range_" + key)
    errors = tags(row.get("data_quality_errors_tags"))
    if errors:
        flags.append("source_quality_errors")
    return {
        "schema_version": 1,
        "id": "off_" + code,
        "source": "open_food_facts",
        "source_id": code,
        "source_url": "https://world.openfoodfacts.org/product/" + code,
        "license": "ODbL-1.0",
        "name": name,
        "name_language": None,
        "brand": (row.get("brands") or "").strip(),
        "quantity": (row.get("quantity") or "").strip(),
        "countries_tags": countries,
        "categories_tags": tags(row.get("categories_tags")),
        "last_modified_t": row.get("last_modified_t") or None,
        "nutrition_as_exported": nutrition,
        "raw_nutrition": raw,
        # OFF's *_100g fields can also mean per 100 ml. CSV omits the
        # metadata needed to resolve this reliably; Poland is not label proof.
        "nutrition_basis": "unknown_100g_or_100ml",
        "carbs_label_mode": "unknown",
        "preparation": "as_sold_not_verified",
        "source_quality_errors": errors,
        "review_flags": sorted(flags),
        "import_ready": False,
    }
