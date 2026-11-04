"""Read official USDA bulk files without importing household portions."""

import hashlib
import json
import math
import re
import unicodedata
import urllib.request
import zipfile

SOURCES = {
    "fndds": ("fndds-2021-2023.zip", "SurveyFoods", "2021-2023", "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_survey_food_json_2024-10-31.zip"),
    "sr_legacy": ("sr-legacy-2018.zip", "SRLegacyFoods", "2018-04", "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_json_2018-04.zip"),
}
NUTRIENTS = {
    1003: ("proteinPer100g", "g"),
    1004: ("fatPer100g", "g"),
    1005: ("carbsPer100g", "g"),
    1079: ("fiberPer100g", "g"),
    1008: ("kcalPer100g", "kcal"),
    1018: ("alcoholPer100g", "g"),
}
MACROS = ("carbsPer100g", "fatPer100g", "fiberPer100g", "proteinPer100g")


def checksum(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def normalized(value):
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    return " ".join(re.findall(r"[a-z0-9]+", value.lower()))


def download(url, path):
    temporary = path.with_suffix(".part")
    with urllib.request.urlopen(url, timeout=120) as response, temporary.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    temporary.replace(path)


def read_source(path, dataset):
    with zipfile.ZipFile(path) as archive:
        names = [name for name in archive.namelist() if name.endswith(".json")]
        if len(names) != 1:
            raise ValueError("Expected exactly one USDA JSON file")
        with archive.open(names[0]) as stream:
            return json.load(stream)[SOURCES[dataset][1]]


def convert(food, dataset):
    fdc_id = food["fdcId"]
    if type(fdc_id) is not int or fdc_id <= 0:
        raise ValueError("Invalid FDC ID")
    name = food["description"].strip()
    if not normalized(name):
        raise ValueError("Empty food name")
    nutrition = {field: None for field, _ in NUTRIENTS.values()}
    for entry in food.get("foodNutrients", []):
        nutrient = entry["nutrient"]
        if nutrient["id"] not in NUTRIENTS:
            continue
        field, unit = NUTRIENTS[nutrient["id"]]
        if nutrient.get("unitName", "").lower() != unit:
            raise ValueError(f"Unexpected unit for {field}")
        value = entry.get("amount")
        if value is None:
            continue
        if type(value) not in (float, int) or not math.isfinite(value) or value < 0:
            raise ValueError(f"Invalid value for {field}")
        if nutrition[field] is not None and nutrition[field] != value:
            raise ValueError(f"Conflicting values for {field}")
        nutrition[field] = float(value)
    return {
        "id": f"usda_{fdc_id}",
        "schemaVersion": 1,
        "ingredientSource": "firebase",
        "sourceIngredientId": f"usda_{fdc_id}",
        "name": name,
        "languageCode": "en",
        "searchName": normalized(name),
        "nutritionBasisGrams": 100,
        "carbsLabelMode": "non_eu",
        "carbohydrateDefinition": "total_including_fiber",
        # In the app, isReference means a special macro entry, not a catalog food.
        "isReference": False,
        **nutrition,
        "category": food.get("foodCategory", {}).get("description") or food.get("wweiaFoodCategory", {}).get("wweiaFoodCategoryDescription"),
        "source": {
            "provider": "USDA FoodData Central",
            "dataset": dataset,
            "release": SOURCES[dataset][2],
            "fdcId": fdc_id,
            "publicationDate": food.get("publicationDate"),
            "url": f"https://fdc.nal.usda.gov/food-details/{fdc_id}/nutrients",
        },
    }


def quality_issues(document):
    issues = []
    for field in MACROS:
        value = document[field]
        if value is None:
            issues.append(f"missing:{field}")
        elif value > 100:
            issues.append(f"out_of_range:{field}")
    if any(document[field] is None for field in MACROS):
        return issues
    carbs, fat, fiber, protein = (document[field] for field in MACROS)
    if fiber > carbs:
        issues.append("fiber_exceeds_total_carbs")
    if carbs + fat + protein > 105:
        issues.append("macro_mass_exceeds_105g")
    if (document["alcoholPer100g"] or 0) > 0:
        issues.append("contains_alcohol")
    energy = document["kcalPer100g"]
    if energy is None:
        issues.append("missing:kcalPer100g")
    else:
        # Screening only: source energy can legitimately use other factors.
        estimate = 4 * protein + 9 * fat + 4 * max(0, carbs - fiber) + 2 * fiber + 7 * (document["alcoholPer100g"] or 0)
        if abs(energy - estimate) > max(40, energy * 0.25):
            issues.append("energy_difference_review")
    return issues


def json_line(value):
    return json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",", ":"))
