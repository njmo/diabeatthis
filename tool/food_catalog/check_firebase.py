"""Read-only Firestore inspection using the Firebase CLI's existing login."""

import argparse
import json
from pathlib import Path

from common.firebase_cli import FirebaseCLI


def unpack(result):
    if result.get("isError"):
        raise RuntimeError("; ".join(item.get("text", "") for item in result.get("content", [])))
    if "structuredContent" in result:
        return result["structuredContent"]
    text = "\n".join(item.get("text", "") for item in result.get("content", []))
    try:
        return json.loads(text)
    except ValueError:
        return text


def inspect(project, database, data_dir):
    context = data_dir / "firebase-context"
    context.mkdir(parents=True, exist_ok=True)
    (context / "firebase.json").write_text("{}\n")
    (context / ".firebaserc").write_text(json.dumps({"projects": {"default": project}}))
    client = FirebaseCLI(project, context)
    base = f"projects/{project}/databases/{database}"
    try:
        metadata = unpack(client.call_read_tool("firestore_get_database", {"name": base}))
        collections = []
        page_token = None
        while True:
            args = {"parent": base + "/documents", "pageSize": 100}
            if page_token:
                args["pageToken"] = page_token
            page = unpack(client.call_read_tool("firestore_list_collections", args))
            collections.extend(page.get("collectionIds", []))
            page_token = page.get("nextPageToken")
            if not page_token:
                break
        # Count only a bounded sample. This is not a whole-collection count.
        sample = unpack(client.call_read_tool("firestore_list_documents", {"parent": base + "/documents/common/ingredients", "collectionId": "items", "pageSize": 1, "mask": {"fieldPaths": ["name", "sourceIngredientId"]}}))
        rules = unpack(client.call_read_tool("firebase_get_security_rules", {"type": "firestore"}))
        report = {
            "project": project,
            "database": database,
            "location": metadata.get("locationId"),
            "edition": metadata.get("databaseEdition"),
            "rootCollections": collections,
            "targetCollection": "common/ingredients/items",
            "targetHasDocuments": bool(sample.get("documents", [])),
            "clientRules": rules,
            "cloudWritesPerformed": False,
        }
        (data_dir / "firebase-check.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))
    finally:
        client.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="diabeatthis-e634c")
    parser.add_argument("--database", default="(default)")
    parser.add_argument("--data-dir", type=Path, default=Path(__file__).parent / "data")
    args = parser.parse_args()
    inspect(args.project, args.database, args.data_dir.resolve())
