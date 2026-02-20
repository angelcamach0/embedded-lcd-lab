#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

run_test() {
  local script_path="$1"
  echo "[RUN] ${script_path#$PROJECT_ROOT/}"
  "$script_path"
}

run_test "$PROJECT_ROOT/scripts/tests/test_duration_policy.sh"
run_test "$PROJECT_ROOT/scripts/tests/test_interactive_parser.sh"

echo "[PASS] all regression scripts passed"
