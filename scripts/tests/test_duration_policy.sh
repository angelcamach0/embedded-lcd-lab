#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source helper functions without running the playlist main loop.
# shellcheck disable=SC1091
source "$PROJECT_ROOT/scripts/run_playlist.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "[FAIL] $msg: expected '$expected' got '$actual'"
    exit 1
  fi
}

assert_empty() {
  local actual="$1"
  local msg="$2"
  if [[ -n "$actual" ]]; then
    echo "[FAIL] $msg: expected empty got '$actual'"
    exit 1
  fi
}

echo "[+] Running duration policy checks"

# HHMMSS parser checks
assert_eq "10" "$(hhmmss_to_seconds "000010")" "HHMMSS 000010"
assert_eq "1800" "$(hhmmss_to_seconds "003000")" "HHMMSS 003000"
assert_eq "420" "$(hhmmss_to_seconds "000700")" "HHMMSS 000700"
assert_empty "$(hhmmss_to_seconds "006060")" "HHMMSS invalid mm/ss"
assert_empty "$(hhmmss_to_seconds "12345")" "HHMMSS invalid length"

# Filename suffix checks (default HHMMSS mode)
ENABLE_LEGACY_TTT_DURATION="false"
assert_eq "420" "$(duration_from_sketch_name "/tmp/02_lcd_matrix_rain_000700.ino")" "filename HHMMSS suffix"
assert_empty "$(duration_from_sketch_name "/tmp/no_suffix.ino")" "filename no suffix"
assert_empty "$(duration_from_sketch_name "/tmp/legacy_060.ino")" "legacy disabled"

# Legacy compatibility checks
ENABLE_LEGACY_TTT_DURATION="true"
assert_eq "60" "$(duration_from_sketch_name "/tmp/legacy_060.ino")" "legacy mss parse"
assert_eq "999" "$(duration_from_sketch_name "/tmp/legacy_999.ino")" "legacy raw fallback"

echo "[PASS] duration policy checks passed"
