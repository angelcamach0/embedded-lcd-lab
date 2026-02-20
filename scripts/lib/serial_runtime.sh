#!/usr/bin/env bash

# Serial-runtime helpers for token watching, weather feed, and timer commands.
# These functions rely on globals and helper functions defined by run_playlist.sh.

wait_for_done_token() {
  # PRE: timeout_seconds is positive integer; DONE_TOKEN/PORT are configured.
  # POST:
  # - returns 0 when token observed
  # - returns 1 on timeout
  # - returns 3 on user skip (Space)
  # - returns 4 when watcher disconnects/fails
  local timeout_seconds="$1"

  need_cmd python3
  run_token_watcher_py "$timeout_seconds" &
  local py_pid=$!

  while kill -0 "$py_pid" >/dev/null 2>&1; do
    if check_space_pressed; then
      kill "$py_pid" >/dev/null 2>&1 || true
      wait "$py_pid" 2>/dev/null || true
      sleep "$POST_SKIP_COOLDOWN_SECONDS"
      return 3
    fi
    sleep 0.1
  done

  wait "$py_pid"
  local rc=$?
  sleep 0.1
  return "$rc"
}

run_token_watcher_py() {
  # Wrapper to external watcher to keep shell script maintainable.
  python3 "$SCRIPT_LIB/token_watcher.py" "$PORT" "$DONE_TOKEN" "$1"
}

run_serial_feed() {
  # PRE: feed_seconds is positive integer duration.
  # POST: serial weather feed runs for feed_seconds unless skipped/interrupted.
  local feed_seconds="$1"
  need_cmd python3

  local weather_meta
  weather_meta="$(
    python3 "$SCRIPT_LIB/weather_meta.py" "$WEATHER_LOCATION" "$WEATHER_LAT" "$WEATHER_LON" "$WEATHER_IP"
  )"
  local weather city tag source
  IFS='|' read -r weather city tag source <<< "$weather_meta"
  weather="${weather:-N/A}"
  city="${city:-City}"
  tag="${tag:---}"
  source="${source:-unknown}"

  weather="$(python3 "$SCRIPT_LIB/sanitize_field.py" weather "$weather")"
  city="$(python3 "$SCRIPT_LIB/sanitize_field.py" city "$city")"
  tag="$(python3 "$SCRIPT_LIB/sanitize_field.py" tag "$tag")"
  echo "[+] Weather value: ${weather}  City: ${city}  Tag: ${tag}  Source: ${source}"

  run_serial_feed_py "$PORT" "$feed_seconds" "$weather" "$city" "$tag" &
  local py_pid=$!
  while kill -0 "$py_pid" >/dev/null 2>&1; do
    if check_space_pressed; then
      kill "$py_pid" >/dev/null 2>&1 || true
      wait "$py_pid" 2>/dev/null || true
      echo "[+] Space pressed: skipping serial feed"
      sleep "$POST_SKIP_COOLDOWN_SECONDS"
      cleanup_background_jobs
      force_release_port_if_owned_by_helpers
      wait_for_port_free "$PORT_WAIT_TIMEOUT_SECONDS" >/dev/null 2>&1 || true
      return 0
    fi
    sleep 0.1
  done
  wait "$py_pid"
  cleanup_background_jobs
  force_release_port_if_owned_by_helpers
  wait_for_port_free "$PORT_WAIT_TIMEOUT_SECONDS" >/dev/null 2>&1 || true
}

run_serial_feed_py() {
  # Wrapper to external serial-feed sender.
  python3 "$SCRIPT_LIB/serial_feed.py" "$1" "$2" "$3" "$4" "$5"
}

is_afoqt_timer_sketch() {
  # PRE: sketch_path is a .ino path string.
  # POST: returns 0 only for designated AFOQT timer sketch names.
  local sketch_path="$1"
  local base
  base="$(basename "$sketch_path")"
  [[ "$base" =~ _afoqt_timer_ ]]
}

send_timer_start_if_applicable() {
  # PRE: current sketch and hold_seconds are resolved for current cycle step.
  # POST: sends timer start command only for AFOQT timer sketches when enabled.
  local current_sketch="$1"
  local hold_seconds="$2"

  if [[ "$ENABLE_TIMER_START_COMMAND" != "true" ]]; then
    return 0
  fi

  if ! is_afoqt_timer_sketch "$current_sketch"; then
    return 0
  fi

  need_cmd python3
  echo "[+] Sending timer start command: ${hold_seconds}s"
  python3 "$SCRIPT_LIB/timer_control.py" "$PORT" START_SECONDS "$hold_seconds" || true
}
