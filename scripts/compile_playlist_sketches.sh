#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKETCH_ROOT="${SKETCH_ROOT:-$PROJECT_ROOT/src/playlist}"
BOARD_FQBN="${BOARD_FQBN:-arduino:avr:uno}"
ARDUINO_CLI="${ARDUINO_CLI:-arduino-cli}"
LOCAL_LIBRARIES_DIR="${LOCAL_LIBRARIES_DIR:-$PROJECT_ROOT/src/common}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

need_cmd "$ARDUINO_CLI"

shopt -s nullglob
files=("$SKETCH_ROOT"/*.ino)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No .ino files found in $SKETCH_ROOT"
  exit 1
fi

for ino in "${files[@]}"; do
  stem="$(basename "${ino%.ino}")"
  stage_root="$(mktemp -d)"
  stage_sketch="$stage_root/$stem"
  mkdir -p "$stage_sketch"
  cp "$ino" "$stage_sketch/$stem.ino"

  echo "[+] Compiling: $ino"
  "$ARDUINO_CLI" compile --libraries "$LOCAL_LIBRARIES_DIR" --fqbn "$BOARD_FQBN" "$stage_sketch"

  rm -rf "$stage_root"
done

echo "[+] Compile pass complete"
