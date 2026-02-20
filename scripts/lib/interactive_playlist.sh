#!/usr/bin/env bash

# Interactive playlist helper functions.
# These rely on shared globals set by run_playlist.sh.

interactive_override_seconds_for_sketch() {
  # PRE:
  # - $1 is a discovered .ino sketch path.
  # - INTERACTIVE_OVERRIDE_NAMES/SECONDS are aligned arrays.
  # POST:
  # - echoes matched override seconds for the sketch basename, or empty.
  local sketch_path="$1"
  local base
  base="$(basename "$sketch_path")"
  local idx
  for idx in "${!INTERACTIVE_OVERRIDE_NAMES[@]}"; do
    if [[ "${INTERACTIVE_OVERRIDE_NAMES[$idx]}" == "$base" ]]; then
      echo "${INTERACTIVE_OVERRIDE_SECONDS[$idx]}"
      return 0
    fi
  done
  echo ""
}

apply_interactive_playlist_selection() {
  # PRE:
  # - SCRIPT_LIB and SKETCH_ROOT are valid.
  # - playlist_interactive.py is available.
  # POST:
  # - SKETCHES and interactive override arrays are updated from user selection.
  # - AUTO_DISCOVER_SKETCHES is forced false for this run.
  # - INTERACTIVE_SELECTION_APPLIED is set true on success.
  need_cmd python3

  local tmp_out
  tmp_out="$(mktemp)"
  if ! python3 "$SCRIPT_LIB/playlist_interactive.py" "$SKETCH_ROOT" >"$tmp_out"; then
    rm -f "$tmp_out"
    echo "[!] Interactive playlist selection failed."
    return 1
  fi

  local selected=()
  INTERACTIVE_OVERRIDE_NAMES=()
  INTERACTIVE_OVERRIDE_SECONDS=()

  while IFS='|' read -r kind a b; do
    case "$kind" in
      SKETCH)
        selected+=("$a")
        ;;
      OVERRIDE)
        if [[ "$b" =~ ^[0-9]+$ ]]; then
          INTERACTIVE_OVERRIDE_NAMES+=("$a")
          INTERACTIVE_OVERRIDE_SECONDS+=("$b")
        fi
        ;;
    esac
  done < "$tmp_out"
  rm -f "$tmp_out"

  if [[ ${#selected[@]} -eq 0 ]]; then
    echo "[!] Interactive selection returned zero sketches."
    return 1
  fi

  SKETCHES=("${selected[@]}")
  AUTO_DISCOVER_SKETCHES="false"
  INTERACTIVE_SELECTION_APPLIED="true"
  echo "[+] Interactive playlist enabled with ${#SKETCHES[@]} sketch(es)."
}
