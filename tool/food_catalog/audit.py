"""Verify all exports and compare every nutrient with its original USDA record."""

import json
from pathlib import Path
import sqlite3

from common.usda import SOURCES, checksum, quality_issues, read_source
from common.icons import IconCatalog
from common.selection import select_group


def audit(data_dir):
    manifest = json.loads((data_dir / "manifest.json").read_text())
    for name, details in manifest["files"].items():
        if checksum(data_dir / name) != details["sha256"]:
            raise ValueError(f"Checksum mismatch: {name}")
    documents = [json.loads(line) for line in (data_dir / "catalog.jsonl").read_text().splitlines()]
    by_id = {doc["id"]: doc for doc in documents}
    if len(by_id) != len(documents) or len(documents) != manifest["records"]:
        raise ValueError("Duplicate identities or unexpected record count")
    checked = 0
    icons = IconCatalog(Path(__file__).resolve().parents[2])
    for doc in documents:
        if icons.paths.get(doc.get("iconId")) != doc.get("iconAssetPath"):
            raise ValueError(f"Unknown bundled icon: {doc['id']}")
    # Deliberately independent mapping for checking the generated export.
    fields = {1003: "proteinPer100g", 1004: "fatPer100g", 1005: "carbsPer100g", 1079: "fiberPer100g", 1008: "kcalPer100g", 1018: "alcoholPer100g"}
    for dataset, (filename, _, _, _) in SOURCES.items():
        if checksum(data_dir / filename) != manifest["sources"][dataset]["sha256"]:
            raise ValueError("Source archive checksum mismatch")
        for source in read_source(data_dir / filename, dataset):
            if select_group(source, dataset) is None:
                if f"usda_{source['fdcId']}" in by_id:
                    raise ValueError("Non-basic food entered the catalog")
                continue
            doc = by_id[f"usda_{source['fdcId']}"]
            if doc["basicFoodGroup"] != select_group(source, dataset):
                raise ValueError("Incorrect basic food classification")
            original = {n["nutrient"]["id"]: n.get("amount") for n in source.get("foodNutrients", [])}
            for nutrient_id, field in fields.items():
                if doc[field] != original.get(nutrient_id):
                    raise ValueError(f"Changed nutrient value: {doc['id']} / {field}")
                checked += 1
            if doc["name"] != source["description"].strip():
                raise ValueError("Changed source name")
            if doc["nutritionBasisGrams"] != 100 or doc["carbsLabelMode"] != "non_eu" or doc["carbohydrateDefinition"] != "total_including_fiber":
                raise ValueError("Invalid nutrition basis or carbohydrate mode")
            if doc["ingredientSource"] != "firebase" or doc["sourceIngredientId"] != doc["id"] or doc["isReference"]:
                raise ValueError("Invalid identity or app ingredient kind")
            if "portions" in doc or "foodPortions" in doc:
                raise ValueError("Portions must not be imported")
    with sqlite3.connect(f"file:{data_dir / 'catalog.sqlite'}?mode=ro", uri=True) as db:
        if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise ValueError("SQLite database is corrupt")
        rows = db.execute("SELECT id,status,issues,document FROM foods").fetchall()
        if len(rows) != len(documents):
            raise ValueError("SQLite/export count mismatch")
        for key, status, issues, raw in rows:
            if json.loads(raw) != by_id[key] or json.loads(issues) != quality_issues(by_id[key]):
                raise ValueError("SQLite/export content mismatch")
            if status == "ready" and json.loads(issues):
                raise ValueError("Flagged record marked ready")
        ready_ids = {key for key, status, _, _ in rows if status == "ready"}
    ready = [json.loads(line) for line in (data_dir / "ready.jsonl").read_text().splitlines()]
    if {doc["id"] for doc in ready} != ready_ids or len(ready) != len(ready_ids):
        raise ValueError("Ready export does not match review statuses")
    for doc in ready:
        if doc != by_id[doc["id"]] or quality_issues(doc):
            raise ValueError("Ready export contains changed or flagged values")
    return {"recordsVerified": len(documents), "sourceNutrientComparisons": checked, "readyRecords": len(ready), "sqliteIntegrity": "ok"}


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, default=Path(__file__).parent / "data")
    args = parser.parse_args()
    print(json.dumps(audit(args.data_dir.resolve()), indent=2))
