#!/usr/bin/env bash

# Serial-port lifecycle helpers used by the playlist runtime.
# These functions assume caller provides PORT and timeout values.

port_busy_pids() {
  # PRE: PORT is a serial device path string.
  # POST: echoes PID list (or empty) for processes holding PORT.
  local pids=""
  if command -v lsof >/dev/null 2>&1; then
    pids="$(lsof -t "$PORT" 2>/dev/null | tr '\n' ' ' || true)"
  elif command -v fuser >/dev/null 2>&1; then
    pids="$(fuser "$PORT" 2>/dev/null | tr '\n' ' ' || true)"
  fi
  echo "$pids"
}

wait_for_port_free() {
  # PRE:
  # - PORT is set.
  # - timeout argument is positive integer seconds.
  # POST:
  # - returns 0 when no owner is detected for PORT before deadline.
  # - returns 1 and prints operator guidance on timeout.
  local timeout="${1:-6}"
  local deadline=$(( $(date +%s) + timeout ))
  while [[ $(date +%s) -lt "$deadline" ]]; do
    local pids
    pids="$(port_busy_pids)"
    if [[ -z "${pids// }" ]]; then
      return 0
    fi
    sleep 0.2
  done
  local pids
  pids="$(port_busy_pids)"
  if [[ -n "${pids// }" ]]; then
    echo "[!] Port $PORT still busy by PID(s): $pids"
    echo "[!] Close Arduino IDE Serial Monitor/Plotter if open, then retry."
    return 1
  fi
  return 0
}

force_release_port_if_owned_by_helpers() {
  # PRE: PORT is set.
  # POST:
  # - attempts to terminate known helper processes that keep PORT open.
  # - leaves unrelated/non-owned processes untouched.
  if ! command -v lsof >/dev/null 2>&1; then
    return 0
  fi

  local pids
  pids="$(lsof -t "$PORT" 2>/dev/null | tr '\n' ' ' || true)"
  [[ -n "${pids// }" ]] || return 0

  local me pid cmd owner killed_any=false
  me="$(id -un)"
  for pid in $pids; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    [[ "$pid" -eq "$$" ]] && continue
    owner="$(ps -o user= -p "$pid" 2>/dev/null | tr -d '[:space:]' || true)"
    cmd="$(ps -o args= -p "$pid" 2>/dev/null || true)"
    if [[ "$owner" == "$me" && ( "$cmd" == *"serial_feed.py"* || "$cmd" == *"token_watcher.py"* || "$cmd" == *"arduino-cli"* ) ]]; then
      kill "$pid" >/dev/null 2>&1 || true
      killed_any=true
    fi
  done

  if [[ "$killed_any" == "true" ]]; then
    sleep 0.35
    pids="$(lsof -t "$PORT" 2>/dev/null | tr '\n' ' ' || true)"
    for pid in $pids; do
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      [[ "$pid" -eq "$$" ]] && continue
      owner="$(ps -o user= -p "$pid" 2>/dev/null | tr -d '[:space:]' || true)"
      cmd="$(ps -o args= -p "$pid" 2>/dev/null || true)"
      if [[ "$owner" == "$me" && ( "$cmd" == *"serial_feed.py"* || "$cmd" == *"token_watcher.py"* || "$cmd" == *"arduino-cli"* ) ]]; then
        kill -9 "$pid" >/dev/null 2>&1 || true
      fi
    done
    sleep 0.25
  fi
}
