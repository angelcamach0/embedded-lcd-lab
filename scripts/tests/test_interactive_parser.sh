#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck disable=SC1091
source "$PROJECT_ROOT/scripts/lib/interactive_playlist.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "[FAIL] $msg: expected '$expected' got '$actual'"
    exit 1
  fi
}

echo "[+] Running interactive parser checks"

tmp="$(mktemp)"
cat > "$tmp" <<'EOF'
SKETCH|/tmp/01.ino
OVERRIDE|06_lcd_afoqt_timer_003000.ino|1800
GARBAGE|x|y
OVERRIDE|bad.ino|notnum
SKETCH|
SKETCH|/tmp/02.ino|extra
OVERRIDE|target.ino|900
EOF

parse_interactive_records_file "$tmp"
rm -f "$tmp"

assert_eq "2" "${#INTERACTIVE_PARSED_SKETCHES[@]}" "valid sketch count"
assert_eq "/tmp/01.ino" "${INTERACTIVE_PARSED_SKETCHES[0]}" "first sketch path preserved"
assert_eq "/tmp/02.ino" "${INTERACTIVE_PARSED_SKETCHES[1]}" "second sketch path preserved"

assert_eq "2" "${#INTERACTIVE_PARSED_OVERRIDE_NAMES[@]}" "valid override count"
assert_eq "06_lcd_afoqt_timer_003000.ino" "${INTERACTIVE_PARSED_OVERRIDE_NAMES[0]}" "first override basename"
assert_eq "1800" "${INTERACTIVE_PARSED_OVERRIDE_SECONDS[0]}" "first override seconds"
assert_eq "target.ino" "${INTERACTIVE_PARSED_OVERRIDE_NAMES[1]}" "second override basename"
assert_eq "900" "${INTERACTIVE_PARSED_OVERRIDE_SECONDS[1]}" "second override seconds"

echo "[PASS] interactive parser checks passed"
