#!/usr/bin/env bash
# check-links.sh — validates relative markdown links.
#
# Walks every .md file in the repo and:
#   1. Extracts every [text](path) inline link.
#   2. For relative links (no scheme): resolves against the file's directory
#      and verifies the target exists. Anchors (#section) are allowed but the
#      target file must still resolve.
#   3. For absolute https:// links to github.com/chthonicsystems/<repo>:
#      verifies the repo exists via `gh repo view` (only if `gh` is on PATH).
#
# Exit 0 if every link resolves; exit 1 with a per-file report otherwise.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
CHECKED_REPOS=""

resolve_relative() {
  local base_dir="$1"
  local link="$2"
  # strip anchor
  local path="${link%%#*}"
  if [[ -z "$path" ]]; then
    # anchor-only link; same file
    echo ""
    return
  fi
  if [[ "$path" = /* ]]; then
    # absolute repo path
    echo "$REPO_ROOT$path"
  else
    # relative path — resolve via python (portable on macOS without GNU realpath -m)
    python3 -c "import os, sys; print(os.path.normpath(os.path.join(sys.argv[1], sys.argv[2])))" "$base_dir" "$path"
  fi
}

check_file() {
  local file="$1"
  local rel="${file#$REPO_ROOT/}"
  local base_dir
  base_dir="$(dirname "$file")"
  local errors=()

  # Extract markdown inline links: [text](url)
  # Also extract reference-style would be a future enhancement.
  local links
  links="$(grep -oE '\[[^]]*\]\([^)]+\)' "$file" | sed -E 's/^\[[^]]*\]\(([^)]+)\)$/\1/' || true)"

  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    # Skip mailto:, anchors-only, code spans
    [[ "$link" =~ ^mailto: ]] && continue

    if [[ "$link" =~ ^https?:// ]]; then
      # External URL — only validate chthonicsystems/<repo> refs.
      if [[ "$link" =~ ^https://github\.com/chthonicsystems/([a-zA-Z0-9._-]+)(/.*)?$ ]]; then
        local repo_name="${BASH_REMATCH[1]}"
        if [[ ",$CHECKED_REPOS," != *",$repo_name,"* ]]; then
          if command -v gh >/dev/null 2>&1; then
            if ! gh repo view "chthonicsystems/$repo_name" >/dev/null 2>&1; then
              errors+=("external repo not found: chthonicsystems/$repo_name")
            fi
          fi
          CHECKED_REPOS="$CHECKED_REPOS,$repo_name"
        fi
      fi
      continue
    fi

    # Relative link
    local target_path
    target_path="$(resolve_relative "$base_dir" "$link")"
    if [[ -z "$target_path" ]]; then
      # anchor-only link to same file; assume ok
      continue
    fi
    # Strip anchor
    target_path="${target_path%%#*}"
    if [[ ! -e "$target_path" ]]; then
      errors+=("broken relative link: $link  →  $target_path")
    fi
  done <<< "$links"

  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "FAIL: $rel"
    for err in "${errors[@]}"; do
      echo "  - $err"
    done
    FAIL=1
  fi
}

count=0
while IFS= read -r -d '' file; do
  count=$((count + 1))
  check_file "$file"
done < <(find "$REPO_ROOT" \( -path '*/node_modules' -o -path '*/.git' \) -prune -o -name '*.md' -print0)

if [[ $FAIL -eq 0 ]]; then
  echo "OK: $count markdown files; all relative + chthonicsystems/* links resolve"
fi
exit $FAIL
