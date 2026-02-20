#!/usr/bin/env bash

# Pure helpers for playlist timing/override decisions.
# These functions avoid side effects so orchestration code can remain focused.

dp_hhmmss_to_seconds() {
  # PRE: $1 is candidate HHMMSS text.
  # POST: echoes seconds for valid HHMMSS (MM/SS <= 59), else empty string.
  local hhmmss="$1"
  local hrs mins secs
  if [[ ! "$hhmmss" =~ ^[0-9]{6}$ ]]; then
    echo ""
    return 0
  fi
  hrs=$((10#${hhmmss:0:2}))
  mins=$((10#${hhmmss:2:2}))
  secs=$((10#${hhmmss:4:2}))
  if (( mins > 59 || secs > 59 )); then
    echo ""
    return 0
  fi
  echo $((hrs * 3600 + mins * 60 + secs))
}

dp_duration_from_sketch_name() {
  # PRE:
  # - $1 is sketch path or basename ending with .ino.
  # - $2 is legacy toggle: true|false.
  # POST:
  # - echoes derived seconds when filename has a valid duration suffix.
  # - echoes empty string when no valid suffix is present.
  local sketch_path="$1"
  local enable_legacy_ttt_duration="${2:-false}"
  local base stem hhmmss ttt hrs mins secs
  base="$(basename "$sketch_path")"
  stem="${base%.ino}"

  if [[ "$stem" =~ _([0-9]{6})$ ]]; then
    hhmmss="${BASH_REMATCH[1]}"
    hrs=$((10#${hhmmss:0:2}))
    mins=$((10#${hhmmss:2:2}))
    secs=$((10#${hhmmss:4:2}))
    if (( mins <= 59 && secs <= 59 )); then
      echo $((hrs * 3600 + mins * 60 + secs))
      return 0
    fi
    echo ""
    return 0
  fi

  if [[ "$enable_legacy_ttt_duration" == "true" && "$stem" =~ _([0-9]{3})$ ]]; then
    ttt="${BASH_REMATCH[1]}"
    mins=$((10#${ttt:0:1}))
    secs=$((10#${ttt:1:2}))
    if (( secs <= 59 )); then
      echo $((mins * 60 + secs))
      return 0
    fi

    # Compatibility fallback for legacy values.
    echo $((10#$ttt))
    return 0
  fi

  echo ""
}

dp_should_apply_override() {
  # PRE:
  # - mode is one of: global|index|sketch|none.
  # - selectors already validated by caller.
  # POST:
  # - returns 0 when override applies for current sketch/index, else non-zero.
  local mode="$1"
  local target_index="$2"
  local target_basename="$3"
  local current_sketch="$4"
  local current_index="$5"
  local current_basename
  current_basename="$(basename "$current_sketch")"

  if [[ "$mode" == "global" ]]; then
    return 0
  fi
  if [[ "$mode" == "index" && "$current_index" -eq "$target_index" ]]; then
    return 0
  fi
  if [[ "$mode" == "sketch" && "$current_basename" == "$target_basename" ]]; then
    return 0
  fi
  return 1
}
