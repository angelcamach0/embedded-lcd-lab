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

assert_pair() {
  local expected_seconds="$1"
  local expected_source="$2"
  local pair="$3"
  local msg="$4"
  local got_seconds="${pair%%|*}"
  local got_source="${pair#*|}"
  if [[ "$got_seconds" != "$expected_seconds" || "$got_source" != "$expected_source" ]]; then
    echo "[FAIL] $msg: expected ${expected_seconds}|${expected_source} got ${pair}"
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

assert_rc() {
  local expected="$1"
  local msg="$2"
  shift 2
  local rc=0
  if "$@"; then
    rc=0
  else
    rc=$?
  fi
  if [[ "$rc" -ne "$expected" ]]; then
    echo "[FAIL] $msg: expected rc=$expected got rc=$rc"
    exit 1
  fi
}

echo "[+] Running duration policy checks"

# HHMMSS parser checks
assert_eq "10" "$(hhmmss_to_seconds "000010")" "HHMMSS 000010"
assert_eq "1800" "$(hhmmss_to_seconds "003000")" "HHMMSS 003000"
assert_eq "420" "$(hhmmss_to_seconds "000700")" "HHMMSS 000700"
assert_eq "359999" "$(hhmmss_to_seconds "995959")" "HHMMSS max display-safe bound"
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

# Override targeting predicate checks
assert_rc 0 "override global matches any sketch/index" \
  dp_should_apply_override "global" 0 "" "/tmp/a.ino" 1
assert_rc 0 "override index matches selected 1-based index" \
  dp_should_apply_override "index" 2 "" "/tmp/a.ino" 2
assert_rc 1 "override index does not match other indices" \
  dp_should_apply_override "index" 2 "" "/tmp/a.ino" 1
assert_rc 0 "override sketch matches basename" \
  dp_should_apply_override "sketch" 0 "target.ino" "/tmp/target.ino" 5
assert_rc 1 "override sketch does not match non-target basename" \
  dp_should_apply_override "sketch" 0 "target.ino" "/tmp/other.ino" 5
assert_rc 1 "override none never applies" \
  dp_should_apply_override "none" 0 "" "/tmp/a.ino" 1

# Override precedence checks via run_playlist resolver:
# interactive_override > targeted/global override > filename_hhmmss > base/default.
ENABLE_LEGACY_TTT_DURATION="false"
global_override_seconds="1800"
override_mode="global"
override_index_1_based=0
override_basename=""
INTERACTIVE_OVERRIDE_NAMES=("demo_000700.ino")
INTERACTIVE_OVERRIDE_SECONDS=("900")
pair="$(resolve_effective_duration "/tmp/demo_000700.ino" 1 30 "default")"
assert_pair "900" "interactive_override" "$pair" "interactive override precedence"

INTERACTIVE_OVERRIDE_NAMES=()
INTERACTIVE_OVERRIDE_SECONDS=()
pair="$(resolve_effective_duration "/tmp/demo_000700.ino" 1 30 "default")"
assert_pair "1800" "global_override" "$pair" "global override precedence over filename"

global_override_seconds=""
override_mode="none"
pair="$(resolve_effective_duration "/tmp/demo_000700.ino" 1 30 "default")"
assert_pair "420" "filename_hhmmss" "$pair" "filename precedence over base"

echo "[PASS] duration policy checks passed"
