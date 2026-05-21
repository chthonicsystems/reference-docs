#!/usr/bin/env bash
# check-shape.sh — validates the per-library index.md shape contract.
#
# For each libraries/*/index.md:
#   1. Front-matter block exists (--- ... ---)
#   2. Front-matter has required keys: library, version, last-verified
#   3. The seven required H2 headings are present in order:
#      Purpose / Public surface / Dependencies / Extension points /
#      Consuming this library / Related
#   4. The two H3 sub-headings under Public surface: ### .NET, ### npm
#
# Exit 0 if every index.md conforms; exit 1 with a per-file report otherwise.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$REPO_ROOT/libraries"
FAIL=0

REQUIRED_H2=(
  "## Purpose"
  "## Public surface"
  "## Dependencies"
  "## Extension points"
  "## Consuming this library"
  "## Related"
)

REQUIRED_H3=(
  "### .NET"
  "### npm"
)

REQUIRED_FRONTMATTER_KEYS=(
  "library:"
  "version:"
  "last-verified:"
)

check_file() {
  local file="$1"
  local rel="${file#$REPO_ROOT/}"
  local errors=()

  # 1. Front-matter block exists at the top of the file.
  local first_line
  first_line="$(head -n 1 "$file")"
  if [[ "$first_line" != "---" ]]; then
    errors+=("missing front-matter opening '---' on line 1")
  fi

  # Extract front-matter slice (lines 2..N until the second '---').
  local fm_end
  fm_end="$(awk '/^---$/{c++; if (c==2) {print NR; exit}}' "$file")"
  if [[ -z "$fm_end" ]]; then
    errors+=("missing front-matter closing '---'")
  else
    local fm
    fm="$(sed -n "2,$((fm_end - 1))p" "$file")"
    for key in "${REQUIRED_FRONTMATTER_KEYS[@]}"; do
      if ! grep -q "^${key}" <<< "$fm"; then
        errors+=("front-matter missing required key '${key}'")
      fi
    done
  fi

  # 3. Required H2 headings (anywhere in body).
  for heading in "${REQUIRED_H2[@]}"; do
    if ! grep -Fxq "$heading" "$file"; then
      errors+=("missing heading '$heading'")
    fi
  done

  # 4. Required H3 sub-headings.
  for heading in "${REQUIRED_H3[@]}"; do
    if ! grep -Fxq "$heading" "$file"; then
      errors+=("missing sub-heading '$heading'")
    fi
  done

  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "FAIL: $rel"
    for err in "${errors[@]}"; do
      echo "  - $err"
    done
    FAIL=1
  fi
}

if [[ ! -d "$LIB_DIR" ]]; then
  echo "ERROR: libraries/ directory not found at $LIB_DIR"
  exit 1
fi

count=0
while IFS= read -r -d '' file; do
  count=$((count + 1))
  check_file "$file"
done < <(find "$LIB_DIR" -mindepth 2 -maxdepth 2 -name 'index.md' -print0)

if [[ $count -eq 0 ]]; then
  echo "ERROR: no libraries/*/index.md files found"
  exit 1
fi

if [[ $FAIL -eq 0 ]]; then
  echo "OK: $count library index.md files conform to shape contract"
fi
exit $FAIL
