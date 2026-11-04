#!/usr/bin/env python3
"""Build an isolated, auditable Polish-market OFF staging catalog from TSV.gz."""

import argparse
from collections import Counter
import csv
from datetime import datetime, timezone
import gzip
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import time
import uuid

from common.products import NUTRIENTS, product_from_row, search_text, tags

SOURCE_URL = "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"
ROOT = Path(__file__).resolve().parent


def prepare(source, output):
    destination = output
    generations = destination / "generations"
    generations.mkdir(parents=True, exist_ok=True)
    initial_stat = source.stat()
    digest = hashlib.sha256()
    with source.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    source_hash = digest.hexdigest()
    generation = source_hash[:12] + "-" + uuid.uuid4().hex[:12]
    output = generations / (generation + ".partial")
    output.mkdir()
    database = output / "catalog.sqlite.partial"
    if database.exists():
        database.unlink()
    counts = Counter()
    flags = Counter()
    started = time.monotonic()
    with sqlite3.connect(database) as db:
        db.execute("CREATE TABLE products (id TEXT PRIMARY KEY, code TEXT UNIQUE, name TEXT, brand TEXT, document TEXT NOT NULL)")
        db.execute("CREATE VIRTUAL TABLE product_search USING fts5(id UNINDEXED, text, tokenize='unicode61 remove_diacritics 2')")
        csv.field_size_limit(16 * 1024 * 1024)
        with gzip.open(source, "rt", encoding="utf-8", newline="") as stream:
            reader = csv.DictReader(stream, delimiter="\t")
            required = {"code", "countries_tags", "product_name", *NUTRIENTS.values()}
            missing = required.difference(reader.fieldnames or [])
            if missing:
                raise ValueError("Missing export columns: " + ", ".join(sorted(missing)))
            for row in reader:
                counts["source_rows"] += 1
                if None in row or any(value is None for value in row.values()):
                    raise ValueError(f"Malformed TSV row {counts['source_rows']}")
                record = product_from_row(row)
                if record is None:
                    if "en:poland" in tags(row.get("countries_tags")):
                        counts["poland_invalid_identity"] += 1
                    else:
                        counts["outside_country_filter"] += 1
                    continue
                payload = json.dumps(record, ensure_ascii=False, allow_nan=False, separators=(",", ":"))
                try:
                    db.execute("INSERT INTO products VALUES (?, ?, ?, ?, ?)",
                               (record["id"], record["source_id"], record["name"], record["brand"], payload))
                except sqlite3.IntegrityError as error:
                    raise ValueError("Duplicate OFF identity: " + record["id"]) from error
                db.execute("INSERT INTO product_search VALUES (?, ?)",
                           (record["id"], search_text(record["name"] + " " + record["brand"])))
                counts["poland_products"] += 1
                if all(record["nutrition_as_exported"][key] is not None for key in ("carbs", "fat", "protein")):
                    counts["products_with_core_macros"] += 1
                flags.update(record["review_flags"])
                if counts["poland_products"] % 10000 == 0:
                    print(json.dumps(dict(counts)), flush=True)
        db.commit()
        if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise ValueError("Staging database integrity check failed")
        db.execute("INSERT INTO product_search(product_search) VALUES ('integrity-check')")
        jsonl = output / "products-pl.jsonl.partial"
        review = output / "review.csv.partial"
        with jsonl.open("w", encoding="utf-8") as lines, review.open("w", encoding="utf-8", newline="") as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(["id", "name", "brand", "quantity", *NUTRIENTS, "review_flags"])
            for (payload,) in db.execute("SELECT document FROM products ORDER BY code"):
                lines.write(payload + "\n")
                record = json.loads(payload)
                # Prevent spreadsheet formula execution in the review file.
                safe = lambda value: "'" + value if value.startswith(("=", "+", "-", "@", "\t", "\r")) else value
                writer.writerow([record["id"], safe(record["name"]), safe(record["brand"]), safe(record["quantity"]),
                                 *(record["nutrition_as_exported"][key] for key in NUTRIENTS),
                                 ";".join(record["review_flags"])])
        db.commit()
    database.replace(output / "catalog.sqlite")
    jsonl.replace(output / "products-pl.jsonl")
    review.replace(output / "review.csv")
    final_stat = source.stat()
    if (initial_stat.st_size, initial_stat.st_mtime_ns, initial_stat.st_ino) != (final_stat.st_size, final_stat.st_mtime_ns, final_stat.st_ino):
        raise ValueError("Source changed during preparation; generation not published")
    manifest = {
        "schema_version": 1, "created_at": datetime.now(timezone.utc).isoformat(),
        "source_url": SOURCE_URL, "source_sha256": source_hash,
        "source_bytes": source.stat().st_size, "country_filter": "en:poland",
        "license": "ODbL-1.0", "license_url": "https://opendatacommons.org/licenses/odbl/1-0/",
        "attribution": "Contains information from Open Food Facts, available under ODbL 1.0.",
        "counts": dict(counts), "review_flags": dict(flags), "import_ready": False,
        "elapsed_seconds": round(time.monotonic() - started, 2),
        "limitations": ["Market availability is not manufacturing origin or name language.",
                         "CSV nutrition can be per 100 g or 100 ml; basis must be hydrated and verified.",
                         "Carbohydrate convention is not inferred from country.",
                         "Missing, invalid and zero nutrient values remain distinct.",
                         "Products are as sold; no cooked-food conversion is attempted."]}
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    # Publish one complete generation; readers resolve current once per operation.
    finished = generations / generation
    output.rename(finished)
    pointer = destination / (".current-" + uuid.uuid4().hex)
    pointer.symlink_to(Path("generations") / generation, target_is_directory=True)
    os.replace(pointer, destination / "current")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=ROOT / "data/products.tsv.gz")
    parser.add_argument("--output", type=Path, default=ROOT / "data/poland")
    args = parser.parse_args()
    prepare(args.input, args.output)
