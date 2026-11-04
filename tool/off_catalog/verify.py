#!/usr/bin/env python3
"""Independently check the published OFF staging generation and example searches."""

import argparse
from collections import Counter
import json
from pathlib import Path
import sqlite3

from common.products import search_text


def verify(directory):
    generation = directory.resolve(strict=True)
    manifest = json.loads((generation / "manifest.json").read_text())
    counts = manifest["counts"]
    assert counts["source_rows"] == sum(counts.get(key, 0) for key in (
        "outside_country_filter", "poland_invalid_identity", "poland_products", "removed_without_name"))
    flags = Counter()
    lines = 0
    with sqlite3.connect(f"file:{generation / 'catalog.sqlite'}?mode=ro", uri=True) as db:
        assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        assert db.execute("SELECT count(*) FROM products").fetchone()[0] == counts["poland_products"]
        assert db.execute("SELECT count(*) FROM product_search").fetchone()[0] == counts["poland_products"]
        with (generation / "products-pl.jsonl").open() as stream:
            for line in stream:
                record = json.loads(line)
                assert record["id"] == "off_" + record["source_id"]
                assert "en:poland" in record["countries_tags"]
                assert record["nutrition_basis"] == "unknown_100g_or_100ml"
                assert record["carbs_label_mode"] == "unknown"
                assert record["import_ready"] is False
                assert record["license"] == "ODbL-1.0"
                saved = db.execute("SELECT document FROM products WHERE id=?", (record["id"],)).fetchone()
                assert saved is not None and json.loads(saved[0]) == record
                flags.update(record["review_flags"])
                lines += 1
        assert lines == counts["poland_products"]
        assert dict(flags) == manifest["review_flags"]
        examples = {}
        for query in ("Piątnica", "skyr", "Mlekovita", "basmati"):
            result = db.execute(
                "SELECT p.name,p.brand FROM product_search s JOIN products p ON p.id=s.id WHERE product_search MATCH ? LIMIT 5",
                (search_text(query),)).fetchall()
            examples[query] = [{"name": name, "brand": brand} for name, brand in result]
    report = {"verified_products": lines, "generation": generation.name, "search_examples": examples}
    (generation / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path(__file__).resolve().parent / "data/poland/current")
    verify(parser.parse_args().directory)
