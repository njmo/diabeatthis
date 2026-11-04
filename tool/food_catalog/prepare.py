"""One-off download, normalization, local SQLite database and review exports."""

import argparse
import collections
import csv
import html
import json
from pathlib import Path
import sqlite3

from common.usda import MACROS, SOURCES, checksum, convert, download, json_line, quality_issues, read_source
from common.icons import IconCatalog
from common.selection import select_group

DATA_DIR = Path(__file__).parent / "data"


def prepare(data_dir, fetch):
    data_dir.mkdir(parents=True, exist_ok=True)
    records, failures, sources, excluded = [], [], {}, []
    icons = IconCatalog(Path(__file__).resolve().parents[2])
    seen = set()
    for dataset, (filename, _, release, url) in SOURCES.items():
        path = data_dir / filename
        if fetch and not path.exists():
            print(f"Downloading {url}", flush=True)
            download(url, path)
        foods = read_source(path, dataset)
        sources[dataset] = {"count": len(foods), "release": release, "url": url, "sha256": checksum(path)}
        for food in foods:
            group = select_group(food, dataset)
            if group is None:
                excluded.append({"fdcId": food["fdcId"], "name": food["description"], "dataset": dataset})
                continue
            try:
                document = convert(food, dataset)
                document["basicFoodGroup"] = group
                document.update(icons.match(document["name"]))
            except (ValueError, KeyError, TypeError) as error:
                failures.append({"dataset": dataset, "fdcId": food.get("fdcId"), "name": food.get("description"), "error": str(error)})
                continue
            if document["id"] in seen:
                raise ValueError(f"Duplicate FDC identity: {document['id']}")
            seen.add(document["id"])
            issues = quality_issues(document)
            status = "quarantine" if any(issue.startswith(("missing:", "out_of_range:")) for issue in issues) else "needs_review" if issues else "ready"
            records.append({"document": document, "status": status, "issues": issues})
    records.sort(key=lambda row: row["document"]["id"])
    write_database(data_dir / "catalog.sqlite", records)
    for filename, subset in [("catalog.jsonl", records), ("ready.jsonl", [row for row in records if row["status"] == "ready"])]:
        with (data_dir / filename).open("w", encoding="utf-8") as output:
            for row in subset:
                output.write(json_line(row["document"]) + "\n")
    with (data_dir / "review.csv").open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(["id", "dataset", "name", "status", *MACROS, "kcalPer100g", "alcoholPer100g", "iconId", "iconAssetPath", "iconMatchMethod", "issues"])
        for row in records:
            doc = row["document"]
            writer.writerow([doc["id"], doc["source"]["dataset"], doc["name"], row["status"], *(doc[field] for field in MACROS), doc["kcalPer100g"], doc["alcoholPer100g"], doc["iconId"], doc["iconAssetPath"], doc["iconMatchMethod"], ";".join(row["issues"])])
    groups = collections.defaultdict(list)
    for row in records:
        doc = row["document"]
        groups[doc["searchName"]].append(doc["id"])
    duplicates = {name: ids for name, ids in groups.items() if len(ids) > 1}
    (data_dir / "duplicate_names.json").write_text(json.dumps(duplicates, indent=2) + "\n")
    (data_dir / "conversion_failures.json").write_text(json.dumps(failures, indent=2) + "\n")
    (data_dir / "excluded.json").write_text(json.dumps(excluded, indent=2) + "\n")
    report = {
        "schemaVersion": 1,
        "sources": sources,
        "records": len(records),
        "excludedNonBasicFoods": len(excluded),
        "basicFoodGroups": dict(collections.Counter(row["document"]["basicFoodGroup"] for row in records)),
        "statuses": dict(collections.Counter(row["status"] for row in records)),
        "issues": dict(collections.Counter(issue for row in records for issue in row["issues"])),
        "conversionFailures": len(failures),
        "duplicateNameGroups": len(duplicates),
        "iconCatalogSize": len(icons.paths),
        "iconMatches": dict(collections.Counter(row["document"]["iconMatchMethod"] for row in records)),
        "targetCollection": "common/ingredients/items",
        "files": {name: {"sha256": checksum(data_dir / name), "bytes": (data_dir / name).stat().st_size} for name in ["catalog.sqlite", "catalog.jsonl", "ready.jsonl", "review.csv", "duplicate_names.json", "conversion_failures.json"]},
    }
    (data_dir / "manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    write_html(data_dir / "review.html", records, report)
    print(json.dumps(report, indent=2))


def write_database(path, records):
    temporary = path.with_suffix(".tmp")
    temporary.unlink(missing_ok=True)
    with sqlite3.connect(temporary) as db:
        db.execute("CREATE TABLE foods(id TEXT PRIMARY KEY, name TEXT NOT NULL, dataset TEXT NOT NULL, status TEXT NOT NULL, carbs REAL, fat REAL, fiber REAL, protein REAL, kcal REAL, issues TEXT NOT NULL, document TEXT NOT NULL)")
        db.executemany("INSERT INTO foods VALUES(?,?,?,?,?,?,?,?,?,?,?)", [(d["id"], d["name"], d["source"]["dataset"], row["status"], d["carbsPer100g"], d["fatPer100g"], d["fiberPer100g"], d["proteinPer100g"], d["kcalPer100g"], json_line(row["issues"]), json_line(d)) for row in records for d in [row["document"]]])
        db.execute("CREATE INDEX foods_name ON foods(name COLLATE NOCASE)")
        db.execute("CREATE INDEX foods_status ON foods(status)")
        if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise ValueError("SQLite integrity check failed")
    temporary.replace(path)


def write_html(path, records, report):
    # All rows are included for manual review. No scripts or remote resources.
    headers = ["Name", "Dataset", "Status", "Carbs", "Fiber", "Protein", "Fat", "kcal", "Icon", "Issues"]
    parts = ['<!doctype html><html lang="en"><meta charset="utf-8"><title>USDA catalog review</title><style>body{font:14px system-ui;margin:28px;color:#222}table{border-collapse:collapse;width:100%}td,th{padding:7px;text-align:left;border-bottom:1px solid #ddd}th{position:sticky;top:0;background:#eee}.needs_review{background:#fff7df}.quarantine{background:#ffe9e9}a{color:#185abc}</style><h1>USDA catalog review</h1><p>English · all nutrition per 100 g · US total carbohydrates include fiber · no portions</p>']
    parts.append('<pre>' + html.escape(json.dumps({key: report[key] for key in ["records", "statuses", "issues", "conversionFailures", "duplicateNameGroups"]}, indent=2)) + '</pre>')
    parts.append('<p>Ready means automated checks passed, not clinical validation. Source values are preserved. Similar names are retained under distinct source IDs. Search this page using your browser.</p><table><thead><tr>' + ''.join('<th>' + title + '</th>' for title in headers) + '</tr></thead><tbody>')
    for row in sorted(records, key=lambda r: (r["status"] == "ready", r["document"]["name"].lower())):
        d = row["document"]
        cells = [d["source"]["dataset"], row["status"], d["carbsPer100g"], d["fiberPer100g"], d["proteinPer100g"], d["fatPer100g"], d["kcalPer100g"], d["iconId"] + ' (' + d["iconMatchMethod"] + ')', ', '.join(row["issues"])]
        parts.append('<tr class="' + row["status"] + '"><td><a href="' + html.escape(d["source"]["url"], quote=True) + '">' + html.escape(d["name"]) + '</a></td>' + ''.join('<td>' + html.escape('missing' if value is None else str(value)) + '</td>' for value in cells) + '</tr>')
    path.write_text(''.join(parts) + '</tbody></table></html>', encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download", action="store_true")
    parser.add_argument("--data-dir", type=Path, default=DATA_DIR)
    args = parser.parse_args()
    prepare(args.data_dir, args.download)
