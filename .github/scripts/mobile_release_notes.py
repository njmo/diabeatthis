"""Render mobile and Wear OS release notes since the last build available to testers."""

import argparse
import json
import re
import subprocess
from pathlib import Path

NOTES_ROOT = "release-notes"
PLATFORMS = ("android", "ios", "wear")
LIMIT = 500
FALLBACK = {
    "pl-PL": "Poprawki i usprawnienia aplikacji Diabeatthis.",
    "en-US": "Fixes and improvements to Diabeatthis.",
}
WEAR_FALLBACK = {
    "pl-PL": "Poprawki i usprawnienia Diabeatthis na Wear OS.",
    "en-US": "Fixes and improvements to Diabeatthis on Wear OS.",
}
MORE_CHANGES = {
    "pl-PL": "• Oraz inne poprawki.",
    "en-US": "• Plus other improvements.",
}


def git(*args):
    return subprocess.check_output(["git", *args], encoding="utf-8")


def previous_tag(platform, version):
    current = tuple(map(int, version.split(".")))
    candidates = []
    for tag in git("tag", "--merged", "HEAD").splitlines():
        match = re.fullmatch(rf"published-{platform}-v(\d+)\.(\d+)\.(\d+)", tag)
        if not match:
            continue
        number = tuple(map(int, match.groups()))
        if number < current:
            candidates.append((number, tag))
    return max(candidates)[1] if candidates else None


def load_changes(platform, baseline):
    if baseline:
        paths = git("diff", "--name-only", "--diff-filter=A", "-z", baseline, "HEAD", "--", NOTES_ROOT)
    else:
        paths = git("ls-tree", "-r", "--name-only", "-z", "HEAD", "--", NOTES_ROOT)

    changes = []
    for path in sorted(paths.split("\0")):
        if not path.endswith(".json"):
            continue
        entry = json.loads(git("show", f"HEAD:{path}"))
        platforms = entry.get("platforms")
        if not isinstance(platforms, list) or not platforms or any(
            item not in PLATFORMS for item in platforms
        ):
            raise ValueError(f"{path}: specify one or more of android, ios, and wear in platforms")
        notes = {}
        for locale in FALLBACK:
            value = entry.get(locale)
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"{path}: add user-facing copy for {locale}")
            notes[locale] = "• " + " ".join(value.split())
            entry_limit = LIMIT - len(MORE_CHANGES[locale]) - 1
            if len(notes[locale]) > entry_limit:
                raise ValueError(f"{path}: shorten the {locale} entry to {entry_limit - 2} characters")
        if platform in platforms:
            changes.append(notes)
    return changes


def render(changes, platform):
    if not changes:
        return WEAR_FALLBACK if platform == "wear" else FALLBACK

    def join(entries, locale, suffix=False):
        lines = [entry[locale] for entry in entries]
        if suffix:
            lines.append(MORE_CHANGES[locale])
        return "\n".join(lines)

    if all(len(join(changes, locale)) <= LIMIT for locale in FALLBACK):
        return {locale: join(changes, locale) for locale in FALLBACK}

    included = []
    for entry in changes:
        candidate = [*included, entry]
        if all(len(join(candidate, locale, suffix=True)) <= LIMIT for locale in FALLBACK):
            included.append(entry)
    return {locale: join(included, locale, suffix=True) for locale in FALLBACK}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=PLATFORMS)
    parser.add_argument("version")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", args.version):
        parser.error("version must use X.Y.Z")
    baseline = previous_tag(args.platform, args.version)
    changes = load_changes(args.platform, baseline)
    args.output.mkdir(parents=True, exist_ok=True)
    for locale, notes in render(changes, args.platform).items():
        (args.output / f"whatsnew-{locale}").write_text(notes, encoding="utf-8")
    print(f"{args.platform} {args.version}: {len(changes)} entries since {baseline or 'repository start'}")


if __name__ == "__main__":
    main()
