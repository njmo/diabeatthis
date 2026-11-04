"""Validate source-backed nutrition proposals without altering OFF source facts."""

import math

NUTRIENT_KEYS = ("carbs", "fiber", "fat", "protein", "energy_kcal")
CORE = ("carbs", "fat", "protein")


def validate_proposal(record, original):
    errors = []
    if record.get("code") != original["source_id"]:
        return {"status": "hold", "errors": ["identity_mismatch"], "patch": {}, "sources": []}
    if record.get("status") not in ("candidate", "hold", "not_found", "deferred", "excluded_non_food"):
        return {"status": "hold", "errors": ["invalid_research_status"], "patch": {}, "sources": []}
    if record.get("status") != "candidate":
        return {"status": record.get("status", "hold"), "errors": [], "patch": {}, "sources": record.get("sources", [])}
    if record.get("conflicts"):
        errors.append("research_reported_conflict")
    sources = []
    for source in record.get("sources", []):
        values = source.get("nutrition", {})
        url = source.get("url", "")
        if source.get("matched_barcode") != original["source_id"]:
            continue
        if not url.startswith("https://") or source.get("basis_amount") != 100 or source.get("basis_unit") not in ("g", "ml"):
            continue
        valid = True
        for key in NUTRIENT_KEYS:
            value = values.get(key)
            if value is None:
                if key in CORE:
                    valid = False
                continue
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0 or (key != "energy_kcal" and value > 100):
                valid = False
        if valid and sum(values[key] for key in CORE) <= 105:
            sources.append(source)
    if not sources:
        errors.append("no_complete_exact_barcode_source_with_explicit_basis")
    patch = {}
    if sources:
        basis = {(s["basis_amount"], s["basis_unit"]) for s in sources}
        if len(basis) != 1:
            errors.append("conflicting_source_basis")
        for key in NUTRIENT_KEYS:
            values = [s["nutrition"][key] for s in sources if s["nutrition"].get(key) is not None]
            if not values:
                continue
            if any(not math.isclose(v, values[0], rel_tol=0, abs_tol=0.05) for v in values[1:]):
                errors.append("conflicting_sources_" + key)
            previous = original["nutrition_as_exported"].get(key)
            if previous is not None:
                if not math.isclose(previous, values[0], rel_tol=0, abs_tol=0.05):
                    errors.append("conflict_with_off_" + key)
            else:
                patch[key] = values[0]
    return {"status": "hold" if errors else "source_backed_proposal", "errors": sorted(set(errors)),
            "patch": {} if errors else patch, "sources": sources,
            "nutrition_basis": None if errors or not sources else {"amount": 100, "unit": sources[0]["basis_unit"]},
            "carbs_label_mode": "unknown", "publication_approved": False}
