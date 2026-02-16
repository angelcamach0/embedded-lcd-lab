#!/usr/bin/env bash
set -euo pipefail

# Auto-upload a playlist of Arduino sketches and optionally stream weather/time
# data to the serial LCD sketch.
#
# Privacy model:
# - No API keys are used.
# - Weather mode sends only location text OR coordinates to public endpoints.
# - Disable outbound requests by setting ENABLE_SERIAL_FEED=false.

# ---------- USER CONFIG ----------
ARDUINO_CLI="${ARDUINO_CLI:-arduino-cli}"
BOARD_FQBN="${BOARD_FQBN:-arduino:avr:uno}"
PORT="${PORT:-/dev/ttyACM0}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Order matters.
SKETCHES=(
  "$PROJECT_ROOT/src/lcd_wakeup_reveal"
  "$PROJECT_ROOT/src/lcd_matrix_rain"
)

# Optional auto-discovery:
# - true: discover sketch folders under src/ (excluding serial feed helper)
# - false: use SKETCHES array above
AUTO_DISCOVER_SKETCHES=false
SKETCH_ROOT="$PROJECT_ROOT/src"
SKETCH_EXCLUDE_DIRS=("lcd_serial_feed")

# Used when WAIT_FOR_DONE=false or as fallback timeout when token never arrives.
HOLD_SECONDS=(
  30
  30
)
DEFAULT_HOLD_SECONDS=30

# If true, wait for DONE_TOKEN from sketch over serial before switching.
# Sketches that do not emit token will continue after timeout.
WAIT_FOR_DONE=true
DONE_TOKEN="PLAYLIST_DONE"
DONE_TIMEOUT_SECONDS=(
  240
  120
)
DEFAULT_DONE_TIMEOUT_SECONDS=180

# Playlist repetition:
# - 0: infinite loop
# - N>0: run N cycles then stop
PLAYLIST_CYCLES=0

# Serial feed mode uploads lcd_serial_feed and pushes weather/time text.
ENABLE_SERIAL_FEED=true
SERIAL_FEED_SECONDS=60
WEATHER_LOCATION="El Paso"
WEATHER_LAT="${WEATHER_LAT:-}"
WEATHER_LON="${WEATHER_LON:-}"
POST_SKIP_COOLDOWN_SECONDS=1.2
PORT_WAIT_TIMEOUT_SECONDS=6
# -------------------------------

need_cmd() {
  # Fail fast with a clear message when runtime dependencies are missing.
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

cleanup_background_jobs() {
  # Keep serial access single-owner. If watcher/feed children are left alive,
  # uploads can fail due to "port busy" errors.
  local pids
  pids="$(jobs -pr 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    kill ${pids} >/dev/null 2>&1 || true
    wait ${pids} 2>/dev/null || true
  fi
}

port_busy_pids() {
  # Best-effort detection of processes holding the serial port.
  local pids=""
  if command -v lsof >/dev/null 2>&1; then
    pids="$(lsof -t "$PORT" 2>/dev/null | tr '\n' ' ' || true)"
  elif command -v fuser >/dev/null 2>&1; then
    pids="$(fuser "$PORT" 2>/dev/null | tr '\n' ' ' || true)"
  fi
  echo "$pids"
}

wait_for_port_free() {
  # Poll until no process appears to own the serial device.
  local timeout="${1:-$PORT_WAIT_TIMEOUT_SECONDS}"
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

check_space_pressed() {
  # Works only when script is attached to an interactive terminal.
  if [[ ! -t 0 ]]; then
    return 1
  fi

  local key=""
  if IFS= read -rsn1 -t 0.05 key; then
    [[ "$key" == " " ]]
    return
  fi
  return 1
}

sleep_with_skip() {
  # Sleep in short slices so users can skip quickly with Space.
  local seconds="$1"
  local end_ts=$(( $(date +%s) + seconds ))
  while [[ $(date +%s) -lt "$end_ts" ]]; do
    if check_space_pressed; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

is_excluded_dir() {
  local name="$1"
  for excluded in "${SKETCH_EXCLUDE_DIRS[@]}"; do
    if [[ "$name" == "$excluded" ]]; then
      return 0
    fi
  done
  return 1
}

discover_sketches() {
  # Build sketch list dynamically from src/ one level deep.
  # This supports "drop in a folder with .ino and it auto-runs".
  local discovered=()
  while IFS= read -r dir; do
    local base
    base="$(basename "$dir")"
    if is_excluded_dir "$base"; then
      continue
    fi

    # Treat folder as sketch if it contains any .ino file.
    if compgen -G "$dir/*.ino" > /dev/null; then
      discovered+=("$dir")
    fi
  done < <(find "$SKETCH_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)

  if [[ ${#discovered[@]} -eq 0 ]]; then
    echo "No sketches discovered under $SKETCH_ROOT"
    exit 1
  fi

  SKETCHES=("${discovered[@]}")
}

upload_sketch() {
  # Compile first to fail early before touching device state.
  # Upload retries are needed because Uno resets and serial handoff can race.
  local sketch_dir="$1"
  cleanup_background_jobs
  sleep 0.2
  wait_for_port_free "$PORT_WAIT_TIMEOUT_SECONDS" || true
  echo "[+] Uploading: $sketch_dir"
  "$ARDUINO_CLI" compile --fqbn "$BOARD_FQBN" "$sketch_dir"
  local attempt
  for attempt in 1 2 3; do
    wait_for_port_free "$PORT_WAIT_TIMEOUT_SECONDS" || true
    if "$ARDUINO_CLI" upload -p "$PORT" --fqbn "$BOARD_FQBN" "$sketch_dir"; then
      return 0
    fi
    echo "[!] Upload attempt ${attempt} failed; retrying shortly..."
    cleanup_background_jobs
    sleep 1.2
  done
  echo "[!] Upload failed after retries: $sketch_dir"
  return 1
}

wait_for_done_token() {
  # Waits for serial completion token from currently running sketch.
  # Return codes:
  # - 0: token observed
  # - 1: timeout
  # - 3: user skipped via Space
  # - 4: serial watcher couldn't continue
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
  # Embedded Python watcher reads serial lines and exits when DONE_TOKEN appears.
  python3 - "$PORT" "$DONE_TOKEN" "$1" <<'PY'
import sys
import time

try:
    import serial
except Exception:
    print("Missing python module: pyserial")
    sys.exit(2)

port = sys.argv[1]
token = sys.argv[2]
timeout = int(sys.argv[3])

try:
    with serial.Serial(port, 9600, timeout=0.5) as ser:
        # Opening serial can reset Uno; give sketch time to boot.
        time.sleep(2.0)
        end = time.time() + timeout
        while time.time() < end:
            try:
                line = ser.readline().decode("utf-8", "ignore").strip()
            except serial.SerialException as exc:
                print(f"[serial] watcher stopped: {exc}", file=sys.stderr)
                sys.exit(4)
            if line:
                print(f"[serial] {line}")
            if token in line:
                sys.exit(0)
        sys.exit(1)
except serial.SerialException as exc:
    print(f"[serial] unable to open port: {exc}", file=sys.stderr)
    sys.exit(4)
PY
}

run_serial_feed() {
  # Upload the serial-feed sketch, resolve location/temperature metadata, then
  # stream line1|line2 payloads once per second for the configured duration.
  local sketch_dir="$PROJECT_ROOT/src/lcd_serial_feed"
  upload_sketch "$sketch_dir"

  need_cmd python3

  local weather_meta
  weather_meta="$(
    python3 - "$WEATHER_LOCATION" "$WEATHER_LAT" "$WEATHER_LON" <<'PY'
import json
import sys
import urllib.parse
import urllib.request

location = sys.argv[1]
lat_arg = sys.argv[2].strip()
lon_arg = sys.argv[3].strip()

STATE_ABBR = {
    "Alabama":"AL","Alaska":"AK","Arizona":"AZ","Arkansas":"AR","California":"CA",
    "Colorado":"CO","Connecticut":"CT","Delaware":"DE","Florida":"FL","Georgia":"GA",
    "Hawaii":"HI","Idaho":"ID","Illinois":"IL","Indiana":"IN","Iowa":"IA","Kansas":"KS",
    "Kentucky":"KY","Louisiana":"LA","Maine":"ME","Maryland":"MD","Massachusetts":"MA",
    "Michigan":"MI","Minnesota":"MN","Mississippi":"MS","Missouri":"MO","Montana":"MT",
    "Nebraska":"NE","Nevada":"NV","New Hampshire":"NH","New Jersey":"NJ","New Mexico":"NM",
    "New York":"NY","North Carolina":"NC","North Dakota":"ND","Ohio":"OH","Oklahoma":"OK",
    "Oregon":"OR","Pennsylvania":"PA","Rhode Island":"RI","South Carolina":"SC","South Dakota":"SD",
    "Tennessee":"TN","Texas":"TX","Utah":"UT","Vermont":"VT","Virginia":"VA","Washington":"WA",
    "West Virginia":"WV","Wisconsin":"WI","Wyoming":"WY","District of Columbia":"DC",
}

def fetch_text(url: str, timeout: int = 8) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "embedded-lcd-lab"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", "ignore").strip()

def fetch_json(url: str, timeout: int = 8):
    return json.loads(fetch_text(url, timeout=timeout))

def clean_ascii(s: str) -> str:
    s = (s or "").strip()
    return "".join(ch for ch in s if 32 <= ord(ch) <= 126)

def state_tag(admin1: str, country_code: str) -> str:
    admin1 = clean_ascii(admin1)
    cc = clean_ascii(country_code).upper()
    if cc == "US":
        if len(admin1) == 2 and admin1.isalpha():
            return admin1.upper()
        return STATE_ABBR.get(admin1, "US")
    if len(cc) == 2:
        return cc
    return "--"

city = clean_ascii(location) or "City"
tag = "--"
lat = None
lon = None

# 1) Resolve location metadata.
# This step determines city/tag and optional coordinates.
try:
    if lat_arg and lon_arg:
        lat = float(lat_arg)
        lon = float(lon_arg)
        rev = fetch_json(
            f"https://geocoding-api.open-meteo.com/v1/reverse?latitude={lat}&longitude={lon}&count=1"
        )
        results = rev.get("results") or []
        if results:
            city = clean_ascii(results[0].get("name") or city)
            tag = state_tag(results[0].get("admin1", ""), results[0].get("country_code", ""))
    else:
        q = urllib.parse.quote(location)
        geo = fetch_json(f"https://geocoding-api.open-meteo.com/v1/search?name={q}&count=1")
        results = geo.get("results") or []
        if not results:
            raise RuntimeError("location not found")
        lat = float(results[0]["latitude"])
        lon = float(results[0]["longitude"])
        city = clean_ascii(results[0].get("name") or city)
        tag = state_tag(results[0].get("admin1", ""), results[0].get("country_code", ""))
except Exception as exc:
    print(f"[weather] geocode failed: {exc}", file=sys.stderr)
    # Keep defaults and continue with weather fallback below.

# 2) Open-Meteo current temperature.
# Prefer Open-Meteo for machine-readable JSON.
try:
    if lat is None or lon is None:
        raise RuntimeError("missing coordinates")
    wx = fetch_json(
        f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m"
    )
    temp = wx.get("current", {}).get("temperature_2m")
    if temp is None:
        raise RuntimeError("missing temperature")
    weather = f"{float(temp):.1f}C"
    print(f"{weather}|{city}|{tag}")
    raise SystemExit(0)
except Exception as exc:
    print(f"[weather] open-meteo failed: {exc}", file=sys.stderr)

# 3) Fallback to wttr.in if Open-Meteo fails.
# Keep pipeline resilient when one provider times out.
try:
    q = urllib.parse.quote(city)
    wttr = fetch_text(f"https://wttr.in/{q}?format=%t", timeout=8)
    wttr = wttr.replace(" ", "")
    if wttr:
        print(f"{wttr}|{city}|{tag}")
        raise SystemExit(0)
except Exception as exc:
    print(f"[weather] wttr.in failed: {exc}", file=sys.stderr)

print(f"N/A|{city}|{tag}")
PY
  )"
  local weather city tag
  IFS='|' read -r weather city tag <<< "$weather_meta"
  weather="${weather:-N/A}"
  city="${city:-City}"
  tag="${tag:---}"

  weather="$(
    python3 - "$weather" <<'PY'
import re
import sys

w = (sys.argv[1] or "N/A").strip()
# Keep only ASCII characters useful for compact weather text on 16x2 LCD.
w = w.replace("°", "")
w = re.sub(r"[^0-9A-Za-z+./-]", "", w)
print(w[:8] if w else "N/A")
PY
  )"
  city="$(
    python3 - "$city" <<'PY'
import re
import sys
c = (sys.argv[1] or "City").strip()
c = re.sub(r"[^0-9A-Za-z .-]", "", c)
print((c[:10] if c else "City"))
PY
  )"
  tag="$(
    python3 - "$tag" <<'PY'
import re
import sys
t = (sys.argv[1] or "--").strip().upper()
t = re.sub(r"[^A-Z0-9]", "", t)
print((t[:2] if t else "--"))
PY
  )"
  echo "[+] Weather value: ${weather}  City: ${city}  Tag: ${tag}"

  run_serial_feed_py "$PORT" "$SERIAL_FEED_SECONDS" "$weather" "$city" "$tag" &
  local py_pid=$!
  while kill -0 "$py_pid" >/dev/null 2>&1; do
    if check_space_pressed; then
      kill "$py_pid" >/dev/null 2>&1 || true
      wait "$py_pid" 2>/dev/null || true
      echo "[+] Space pressed: skipping serial feed"
      sleep "$POST_SKIP_COOLDOWN_SECONDS"
      return 0
    fi
    sleep 0.1
  done
  wait "$py_pid"
}

run_serial_feed_py() {
  # Serial sender:
  # - alternates top row time/date every 5s
  # - alternates weather C/F every 5s from one fetched value
  # - writes "line1|line2" once per second
  python3 - "$1" "$2" "$3" "$4" "$5" <<'PY'
import sys
import time
from datetime import datetime
import re

try:
    import serial
except Exception:
    print("Missing python module: pyserial")
    sys.exit(1)

port = sys.argv[1]
duration = int(sys.argv[2])
weather = sys.argv[3]
city = sys.argv[4]
tag = (sys.argv[5] or "--")[:2]

# Parse weather once (expected like "17.1C"), then toggle C/F locally.
temp_c = None
m = re.match(r'^\s*([+-]?\d+(?:\.\d+)?)\s*([CFcf]?)\s*$', weather or "")
if m:
    v = float(m.group(1))
    u = (m.group(2) or "C").upper()
    temp_c = (v - 32.0) * (5.0 / 9.0) if u == "F" else v

try:
    with serial.Serial(port, 9600, timeout=1) as ser:
        # UNO resets when serial opens; wait once for sketch boot.
        time.sleep(2.0)
        end_ts = time.time() + duration
        while time.time() < end_ts:
            now = datetime.now()
            show_date = ((int(time.time()) // 5) % 2) == 1

            # Alternate top row: time <-> date every 5 seconds.
            if show_date:
                base = now.strftime("%b %d %Y")
            else:
                base = now.strftime("%H:%M:%S")

            # Top-right 2 chars reserved for region tag.
            line1_chars = list((base + (" " * 16))[:16])
            if len(tag) >= 1:
                line1_chars[14] = tag[0]
            if len(tag) >= 2:
                line1_chars[15] = tag[1]
            line1 = "".join(line1_chars)

            if temp_c is None:
                wx = weather
            else:
                show_f = ((int(time.time()) // 5) % 2) == 1
                if show_f:
                    v = temp_c * (9.0 / 5.0) + 32.0
                    wx = f"{v:.1f}F"
                else:
                    wx = f"{temp_c:.1f}C"

            line2 = f"Wx {wx} {city}"[:16]
            payload = f"{line1}|{line2}\n"
            try:
                ser.write(payload.encode("utf-8", "ignore"))
                ser.flush()
            except serial.SerialException as exc:
                print(f"[serial-feed] stopped: {exc}", file=sys.stderr)
                sys.exit(0)
            time.sleep(1.0)
except serial.SerialException as exc:
    print(f"[serial-feed] unable to open port: {exc}", file=sys.stderr)
    sys.exit(0)
PY
}

main() {
  # Main playlist engine:
  # 1) upload sketch
  # 2) wait for token or timeout (or skip)
  # 3) optionally run serial weather/time segment
  # 4) repeat by cycle configuration
  need_cmd "$ARDUINO_CLI"
  trap cleanup_background_jobs EXIT

  if [[ "$AUTO_DISCOVER_SKETCHES" == "true" ]]; then
    discover_sketches
  fi

  if [[ ${#SKETCHES[@]} -ne ${#HOLD_SECONDS[@]} ]]; then
    echo "[!] SKETCHES and HOLD_SECONDS length mismatch; using DEFAULT_HOLD_SECONDS=${DEFAULT_HOLD_SECONDS}s"
  fi

  local cycle=0
  while true; do
    cycle=$((cycle + 1))
    echo "[+] Starting playlist cycle ${cycle}"
    echo "[+] Tip: press Space to skip to next item"

    for i in "${!SKETCHES[@]}"; do
      upload_sketch "${SKETCHES[$i]}"

      local hold="${DEFAULT_HOLD_SECONDS}"
      if [[ "$i" -lt "${#HOLD_SECONDS[@]}" ]]; then
        hold="${HOLD_SECONDS[$i]}"
      fi

      if [[ "$WAIT_FOR_DONE" == "true" ]]; then
        local timeout="${DEFAULT_DONE_TIMEOUT_SECONDS}"
        if [[ "$i" -lt "${#DONE_TIMEOUT_SECONDS[@]}" ]]; then
          timeout="${DONE_TIMEOUT_SECONDS[$i]}"
        elif [[ "$i" -lt "${#HOLD_SECONDS[@]}" ]]; then
          timeout="${HOLD_SECONDS[$i]}"
        fi
        echo "[+] Waiting for token '${DONE_TOKEN}' (timeout: ${timeout}s)"
        if wait_for_done_token "$timeout"; then
          echo "[+] Done token received"
        else
          rc=$?
          if [[ "$rc" -eq 3 ]]; then
            echo "[+] Space pressed: skipping to next sketch"
          elif [[ "$rc" -eq 4 ]]; then
            echo "[!] Serial watcher disconnected; continuing"
          else
            echo "[!] Token timeout; continuing to next sketch"
          fi
        fi
      else
        echo "[+] Running for ${hold}s"
        if sleep_with_skip "${hold}"; then
          echo "[+] Space pressed: skipping to next sketch"
        fi
      fi
    done

    if [[ "$ENABLE_SERIAL_FEED" == "true" ]]; then
      echo "[+] Running serial weather/time feed for ${SERIAL_FEED_SECONDS}s"
      run_serial_feed
    fi

    if [[ "$PLAYLIST_CYCLES" -gt 0 && "$cycle" -ge "$PLAYLIST_CYCLES" ]]; then
      break
    fi
  done

  echo "[+] Playlist complete"
}

main "$@"
