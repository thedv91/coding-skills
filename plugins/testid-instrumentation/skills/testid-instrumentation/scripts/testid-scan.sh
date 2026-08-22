#!/usr/bin/env bash
# Test-id survey helper. Wraps the ripgrep invocations the skill needs at Phase 0
# (what does this repo already do?) and Phase 4 (did I break uniqueness or the grep
# round-trip?). The quoting for "attribute value" extraction is fiddly enough to get
# wrong by hand, which is the only reason this file exists.
#
#   testid-scan.sh census [path]              which test-id attributes the repo uses
#   testid-scan.sh values [attr] [path]       every value currently in use, sorted
#   testid-scan.sh dupes  [attr] [path]       values that appear in more than one place
#   testid-scan.sh find   <value> [path]      round-trip: where does this value live?
#
# Defaults: attr=data-testid, path=.  Requires ripgrep (rg).

set -euo pipefail

EXCLUDES=(
  --glob '!**/node_modules/**'
  --glob '!**/dist/**'
  --glob '!**/build/**'
  --glob '!**/.next/**'
  --glob '!**/coverage/**'
  --glob '!**/vendor/**'
)

command -v rg >/dev/null || { echo "ripgrep (rg) is required" >&2; exit 1; }

cmd=${1:-census}

case "$cmd" in
  census)
    path=${2:-.}
    rg -oIN 'data-(testid|test-id|test|cy|qa|automation-id|pw)=' "${EXCLUDES[@]}" "$path" \
      | sort | uniq -c | sort -rn
    ;;

  values)
    attr=${2:-data-testid}
    path=${3:-.}
    rg -oIN --replace '$1' "${attr}=[\"']([^\"']+)" "${EXCLUDES[@]}" "$path" | sort -u
    ;;

  dupes)
    attr=${2:-data-testid}
    path=${3:-.}
    # A value on two source lines means the reverse lookup is ambiguous — either it is a
    # deliberately shared template, or rule 2 is broken.
    rg -oIN --replace '$1' "${attr}=[\"']([^\"']+)" "${EXCLUDES[@]}" "$path" | sort | uniq -d
    ;;

  find)
    value=${2:?usage: testid-scan.sh find <value> [path]}
    path=${3:-.}
    echo "== literal =="
    rg -n --fixed-strings "$value" "${EXCLUDES[@]}" "$path" || true
    # An interpolated id never matches in full; retry on the static head so the round-trip
    # check still proves the value is reachable from a devtools copy-paste.
    prefix=${value%-*}
    if [ "$prefix" != "$value" ]; then
      echo
      echo "== static prefix: ${prefix}- =="
      rg -n --fixed-strings "${prefix}-" "${EXCLUDES[@]}" "$path" || true
    fi
    ;;

  *)
    sed -n '7,12p' "$0" >&2
    exit 2
    ;;
esac
