#!/usr/bin/env bash
set -euo pipefail

# Shared entry point for local and GitHub Actions publishing.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY to owner/repository}"
: "${WIKI_TOKEN:?Set WIKI_TOKEN to a token with Wiki write access}"

wiki_workdir="$(mktemp -d)"
trap 'rm -rf "$wiki_workdir"' EXIT

# Keep credentials out of remote URLs, command arguments and Git configuration.
cat > "$wiki_workdir/askpass" <<'ASKPASS'
#!/usr/bin/env bash
case "$1" in
  *Username*) printf '%s\n' 'x-access-token' ;;
  *Password*) printf '%s\n' "$WIKI_TOKEN" ;;
esac
ASKPASS
chmod 700 "$wiki_workdir/askpass"
export GIT_ASKPASS="$wiki_workdir/askpass"
export GIT_TERMINAL_PROMPT=0

if ! git clone "https://github.com/${GITHUB_REPOSITORY}.wiki.git" "$wiki_workdir/wiki"; then
  echo 'Cannot access Wiki. Create its first page and check WIKI_TOKEN permissions.' >&2
  exit 1
fi

# Publish only source pages; preserve unrelated pages already present in Wiki.
python3 "$project_root/tool/wiki/copy_pages.py" "$project_root/docs/wiki" "$wiki_workdir/wiki"
git -C "$wiki_workdir/wiki" add -- '*.md'
if git -C "$wiki_workdir/wiki" diff --cached --quiet; then
  echo 'Wiki is already up to date.'
  exit 0
fi
git -C "$wiki_workdir/wiki" -c user.name='github-actions[bot]' \
  -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
  commit -m 'codex: Update user documentation'
git -C "$wiki_workdir/wiki" push origin HEAD
