#!/usr/bin/env bash
set -euo pipefail

# Auto-upload a playlist of Arduino sketches and optionally stream weather/time
# data to the serial LCD sketch.
#
# Privacy model:
# - No API keys are used.
# - Weather mode sends only location text OR coordinates to public endpoints.
# - Disable outbound requests by setting ENABLE_SERIAL_FEED=false.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_LIB="$PROJECT_ROOT/scripts/lib"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"
DURATION_POLICY_LIB="$SCRIPT_LIB/duration_policy.sh"
PORT_CONTROL_LIB="$SCRIPT_LIB/port_control.sh"
INTERACTIVE_PLAYLIST_LIB="$SCRIPT_LIB/interactive_playlist.sh"
BUILD_UPLOAD_LIB="$SCRIPT_LIB/build_upload.sh"
SERIAL_RUNTIME_LIB="$SCRIPT_LIB/serial_runtime.sh"

# shellcheck source=./lib/duration_policy.sh
source "$DURATION_POLICY_LIB"
# shellcheck source=./lib/port_control.sh
source "$PORT_CONTROL_LIB"
# shellcheck source=./lib/interactive_playlist.sh
source "$INTERACTIVE_PLAYLIST_LIB"
# shellcheck source=./lib/build_upload.sh
source "$BUILD_UPLOAD_LIB"
# shellcheck source=./lib/serial_runtime.sh
source "$SERIAL_RUNTIME_LIB"

trim_whitespace() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

load_env_file() {
  # Safe .env loader:
  # - supports KEY=VALUE lines
  # - skips blank lines and # comments
  # - rejects invalid variable names
  # - does not execute shell code
  local file="$1"
  [[ -f "$file" ]] || return 0

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    raw_line="${raw_line%$'\r'}"
    local line
    line="$(trim_whitespace "$raw_line")"

    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue

    if [[ "$line" != *"="* ]]; then
      echo "[!] Ignoring malformed .env line: $raw_line"
      continue
    fi

    local key value first last
    key="$(trim_whitespace "${line%%=*}")"
    value="$(trim_whitespace "${line#*=}")"

    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "[!] Ignoring invalid .env key: $key"
      continue
    fi

    # Strip surrounding single/double quotes if present.
    if [[ ${#value} -ge 2 ]]; then
      first="${value:0:1}"
      last="${value: -1}"
      if [[ "$first" == "$last" && ( "$first" == '"' || "$first" == "'" ) ]]; then
        value="${value:1:${#value}-2}"
      fi
    fi

    export "$key=$value"
  done < "$file"
}

load_env_file "$ENV_FILE"

# ---------- USER CONFIG ----------
ARDUINO_CLI="${ARDUINO_CLI:-arduino-cli}"
BOARD_FQBN="${BOARD_FQBN:-arduino:avr:uno}"
PORT="${PORT:-/dev/ttyACM0}"
LOCAL_LIBRARIES_DIR="${LOCAL_LIBRARIES_DIR:-$PROJECT_ROOT/src/common}"

# Order matters.
SKETCHES=(
  "$PROJECT_ROOT/src/playlist/01_lcd_baseline_000010.ino"
  "$PROJECT_ROOT/src/playlist/02_lcd_matrix_rain_000700.ino"
  "$PROJECT_ROOT/src/playlist/03_lcd_wakeup_reveal_000030.ino"
)

# Optional auto-discovery:
# - true: discover .ino files under src/playlist
# - false: use SKETCHES array above
AUTO_DISCOVER_SKETCHES="${AUTO_DISCOVER_SKETCHES:-true}"
SKETCH_ROOT="$PROJECT_ROOT/src/playlist"
SKETCH_EXCLUDE_FILES=()
SERIAL_FEED_SKETCH_FILE="${SERIAL_FEED_SKETCH_FILE:-}"
SERIAL_FEED_SKETCH_PATH=""

# Used when WAIT_FOR_DONE=false or as fallback timeout when token never arrives.
HOLD_SECONDS=(
  30
  30
)
DEFAULT_HOLD_SECONDS=30

# If true, wait for DONE_TOKEN from sketch over serial before switching.
# Sketches that do not emit token will continue after timeout.
WAIT_FOR_DONE="${WAIT_FOR_DONE:-false}"
DONE_TOKEN="${DONE_TOKEN:-PLAYLIST_DONE}"
DONE_TIMEOUT_SECONDS=(
  240
  120
)
DEFAULT_DONE_TIMEOUT_SECONDS=180

# Playlist repetition:
# - 0: infinite loop
# - N>0: run N cycles then stop
PLAYLIST_CYCLES="${PLAYLIST_CYCLES:-0}"

# Serial feed mode uploads 04_lcd_city_datetime_temp_feed and pushes weather/time text.
ENABLE_SERIAL_FEED="${ENABLE_SERIAL_FEED:-true}"
SERIAL_FEED_SECONDS="${SERIAL_FEED_SECONDS:-60}"
WEATHER_LOCATION="${WEATHER_LOCATION:-El Paso}"
WEATHER_LAT="${WEATHER_LAT:-}"
WEATHER_LON="${WEATHER_LON:-}"
WEATHER_IP="${WEATHER_IP:-}"
POST_SKIP_COOLDOWN_SECONDS="${POST_SKIP_COOLDOWN_SECONDS:-1.2}"
PORT_WAIT_TIMEOUT_SECONDS="${PORT_WAIT_TIMEOUT_SECONDS:-6}"
UPLOAD_SETTLE_SECONDS="${UPLOAD_SETTLE_SECONDS:-0.9}"
PRECOMPILE_ONCE="${PRECOMPILE_ONCE:-true}"
BUILD_CACHE_ROOT="${BUILD_CACHE_ROOT:-/tmp/embedded-lcd-lab-build}"
ENABLE_LEGACY_TTT_DURATION="${ENABLE_LEGACY_TTT_DURATION:-false}"
DURATION_OVERRIDE_HHMMSS="${DURATION_OVERRIDE_HHMMSS:-}"
OVERRIDE_INDEX="${OVERRIDE_INDEX:-}"
OVERRIDE_SKETCH="${OVERRIDE_SKETCH:-}"
INTERACTIVE_PLAYLIST="${INTERACTIVE_PLAYLIST:-false}"

INTERACTIVE_OVERRIDE_NAMES=()
INTERACTIVE_OVERRIDE_SECONDS=()
ENABLE_TIMER_START_COMMAND="${ENABLE_TIMER_START_COMMAND:-true}"
INTERACTIVE_SELECTION_APPLIED="false"
PRINT_PLAYLIST_PLAN="${PRINT_PLAYLIST_PLAN:-false}"
# -------------------------------

to_bool() {
  local v
  v="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "$v" in
    1|true|yes|on) printf 'true' ;;
    0|false|no|off) printf 'false' ;;
    *) return 1 ;;
  esac
}

print_usage() {
  cat <<'EOF'
Usage: ./run_playlist.sh [flags]

Flags:
  --auto-discover <true|false>
  --wait-for-done <true|false>
  --cycles <N>                    0 means infinite (default)
  --port <device>
  --enable-serial-feed <true|false>
  --serial-feed-seconds <N>
  --weather-location "<name>"
  --weather-lat <float>
  --weather-lon <float>
  --weather-ip <ip-address>      IPv4 or IPv6, e.g. 8.8.8.8 or 2606:4700:4700::1111
  --upload-settle-seconds <float>
  --precompile-once <true|false> Compile once and reuse build artifacts (default true)
  --enable-legacy-ttt-duration <true|false>
  --duration-override-hhmmss <HHMMSS>  Global runtime duration override
  --override-index <N>                 Apply override to discovered index N only
  --override-sketch <name.ino>         Apply override to specific sketch basename
  --interactive-playlist <true|false>  Prompt for sketch selection before run
  --enable-timer-start-command <true|false>
  --print-playlist-plan <true|false>   Print resolved playlist plan then exit
  --serial-feed-sketch <path-or-file>
  --help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --auto-discover)
        AUTO_DISCOVER_SKETCHES="$(to_bool "${2:-}")" || {
          echo "Invalid value for --auto-discover: ${2:-}"
          exit 2
        }
        shift 2
        ;;
      --wait-for-done)
        WAIT_FOR_DONE="$(to_bool "${2:-}")" || {
          echo "Invalid value for --wait-for-done: ${2:-}"
          exit 2
        }
        shift 2
        ;;
      --cycles)
        PLAYLIST_CYCLES="${2:-}"
        if [[ ! "$PLAYLIST_CYCLES" =~ ^[0-9]+$ ]]; then
          echo "Invalid value for --cycles: ${2:-}"
          exit 2
        fi
        shift 2
        ;;
      --port)
        PORT="${2:-}"
        shift 2
        ;;
      --enable-serial-feed)
        ENABLE_SERIAL_FEED="$(to_bool "${2:-}")" || {
          echo "Invalid value for --enable-serial-feed: ${2:-}"
          exit 2
        }
        shift 2
        ;;
      --serial-feed-seconds)
        SERIAL_FEED_SECONDS="${2:-}"
        if [[ ! "$SERIAL_FEED_SECONDS" =~ ^[0-9]+$ ]]; then
          echo "Invalid value for --serial-feed-seconds: ${2:-}"
          exit 2
        fi
        shift 2
        ;;
      --weather-location)
        WEATHER_LOCATION="${2:-}"
        shift 2
        ;;
      --weather-lat)
        WEATHER_LAT="${2:-}"
        shift 2
        ;;
      --weather-lon)
        WEATHER_LON="${2:-}"
        shift 2
        ;;
      --weather-ip)
        WEATHER_IP="${2:-}"
        shift 2
        ;;
      --upload-settle-seconds)
        UPLOAD_SETTLE_SECONDS="${2:-}"
        if [[ ! "$UPLOAD_SETTLE_SECONDS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
          echo "Invalid value for --upload-settle-seconds: ${2:-}"
          exit 2
        fi
        shift 2
        ;;
      --precompile-once)
        PRECOMPILE_ONCE="$(to_bool "${2:-}")" || {
          echo "Invalid value for --precompile-once: ${2:-}"
          exit 2
        }
        shift 2
        ;;
      --enable-legacy-ttt-duration)
        ENABLE_LEGACY_TTT_DURATION="$(to_bool "${2:-}")" || {
          echo "Invalid value for --enable-legacy-ttt-duration: ${2:-}"
          exit 2
        }
        shift 2
        ;;
      --duration-override-hhmmss)
        DURATION_OVERRIDE_HHMMSS="${2:-}"
        shift 2
        ;;
      --override-index)
        OVERRIDE_INDEX="${2:-}"
        if [[ ! "$OVERRIDE_INDEX" =~ ^[0-9]+$ ]]; then
          echo "Invalid value for --override-index: ${2:-}"
          exit 2
        fi
        shift 2
        ;;
      --override-sketch)
        OVERRIDE_SKETCH="${2:-}"
        shift 2
        ;;
      --interactive-playlist)
        INTERACTIVE_PLAYLIST="$(to_bool "${2:-}")" || {
          echo "Invalid value for --interactive-playlist: ${2:-}"
          exit 2
        }
        shift 2
        ;;
      --enable-timer-start-command)
        ENABLE_TIMER_START_COMMAND="$(to_bool "${2:-}")" || {
          echo "Invalid value for --enable-timer-start-command: ${2:-}"
          exit 2
        }
        shift 2
        ;;
      --print-playlist-plan)
        PRINT_PLAYLIST_PLAN="$(to_bool "${2:-}")" || {
          echo "Invalid value for --print-playlist-plan: ${2:-}"
          exit 2
        }
        shift 2
        ;;
      --serial-feed-sketch)
        SERIAL_FEED_SKETCH_FILE="${2:-}"
        shift 2
        ;;
      --help|-h)
        print_usage
        exit 0
        ;;
      *)
        echo "Unknown flag: $1"
        print_usage
        exit 2
        ;;
    esac
  done
}

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

duration_from_sketch_name() {
  # Wrapper for backwards compatibility with existing callers/tests.
  dp_duration_from_sketch_name "$1" "$ENABLE_LEGACY_TTT_DURATION"
}

hhmmss_to_seconds() {
  # Wrapper for backwards compatibility with existing callers/tests.
  dp_hhmmss_to_seconds "$1"
}

is_excluded_file() {
  local name="$1"
  for excluded in "${SKETCH_EXCLUDE_FILES[@]}"; do
    if [[ "$name" == "$excluded" ]]; then
      return 0
    fi
  done
  return 1
}

resolve_serial_feed_sketch() {
  # Determine the dedicated serial-feed sketch file.
  # Priority:
  # 1) explicit --serial-feed-sketch / SERIAL_FEED_SKETCH_FILE
  # 2) auto-detect by pattern 04_lcd_city_datetime_temp_feed_*.ino
  local candidate=""

  if [[ -n "$SERIAL_FEED_SKETCH_FILE" ]]; then
    if [[ -f "$SERIAL_FEED_SKETCH_FILE" ]]; then
      candidate="$SERIAL_FEED_SKETCH_FILE"
    elif [[ -f "$SKETCH_ROOT/$SERIAL_FEED_SKETCH_FILE" ]]; then
      candidate="$SKETCH_ROOT/$SERIAL_FEED_SKETCH_FILE"
    else
      echo "[!] Serial feed sketch not found: $SERIAL_FEED_SKETCH_FILE"
      exit 1
    fi
  else
    local matches=()
    while IFS= read -r f; do
      matches+=("$f")
    done < <(find "$SKETCH_ROOT" -mindepth 1 -maxdepth 1 -type f -name '04_lcd_city_datetime_temp_feed_*.ino' | sort)

    if [[ ${#matches[@]} -eq 0 ]]; then
      # Backward-compatible fallback if user renamed without suffix.
      if [[ -f "$SKETCH_ROOT/04_lcd_city_datetime_temp_feed.ino" ]]; then
        candidate="$SKETCH_ROOT/04_lcd_city_datetime_temp_feed.ino"
      else
        echo "[!] Could not resolve dedicated serial feed sketch under $SKETCH_ROOT"
        echo "[!] Expected pattern: 04_lcd_city_datetime_temp_feed_*.ino"
        exit 1
      fi
    else
      candidate="${matches[0]}"
      if [[ ${#matches[@]} -gt 1 ]]; then
        echo "[!] Multiple serial feed sketches found; using first sorted:"
        echo "[!]   $(basename "$candidate")"
      fi
    fi
  fi

  SERIAL_FEED_SKETCH_PATH="$candidate"
  SKETCH_EXCLUDE_FILES=()
}

discover_sketches() {
  # Build sketch list dynamically from src/playlist/*.ino.
  # This supports "drop in a .ino and it auto-runs".
  local discovered=()
  local sortable=()
  while IFS= read -r file; do
    local base
    base="$(basename "$file")"
    if is_excluded_file "$base"; then
      continue
    fi

    local stem="${base%.ino}"
    local num_key=999999
    local alpha_key="$stem"
    if [[ "$stem" =~ ^([0-9]+)_(.+)$ ]]; then
      num_key=$((10#${BASH_REMATCH[1]}))
      alpha_key="${BASH_REMATCH[2]}"
    fi
    sortable+=("$(printf '%09d|%s|%s' "$num_key" "$alpha_key" "$file")")
  done < <(find "$SKETCH_ROOT" -mindepth 1 -maxdepth 1 -type f -name '*.ino' | sort)

  if [[ ${#sortable[@]} -eq 0 ]]; then
    echo "No .ino sketches discovered under $SKETCH_ROOT"
    exit 1
  fi

  # Order rule:
  # 1) numeric prefix before first underscore (e.g. 02_name) ascending
  # 2) alphabetical tie-breaker on remaining name
  # 3) full path final tie-breaker
  while IFS='|' read -r _num _alpha path; do
    discovered+=("$path")
  done < <(printf '%s\n' "${sortable[@]}" | sort -t'|' -k1,1n -k2,2 -k3,3)

  SKETCHES=("${discovered[@]}")
}

refresh_discovery_if_enabled() {
  # Keep long-running sessions resilient to file renames/additions/removals.
  # When auto-discovery is on, refresh the in-memory playlist from disk.
  if [[ "$AUTO_DISCOVER_SKETCHES" == "true" ]]; then
    discover_sketches
  fi
}

should_apply_global_override_for_sketch() {
  # PRE:
  # - override_mode set to one of: global/index/sketch/none.
  # - override selectors already validated during startup.
  # POST:
  # - returns 0 when a global override should apply to this sketch.
  local current_sketch="$1"
  local one_based_index="$2"

  dp_should_apply_override \
    "$override_mode" \
    "$override_index_1_based" \
    "$override_basename" \
    "$current_sketch" \
    "$one_based_index"
}

resolve_effective_duration() {
  # PRE:
  # - current_sketch exists.
  # - base_seconds already computed by caller for the current mode.
  # POST:
  # - echoes "<seconds>|<source>" where source is one of:
  #   default,array,done_timeout_array,hold_array_fallback,filename_hhmmss,
  #   global_override,interactive_override.
  local current_sketch="$1"
  local one_based_index="$2"
  local base_seconds="$3"
  local base_source="$4"

  local effective="$base_seconds"
  local source="$base_source"

  local name_duration=""
  name_duration="$(duration_from_sketch_name "$current_sketch")"
  if [[ -n "$name_duration" ]]; then
    effective="$name_duration"
    source="filename_hhmmss"
  fi

  if [[ -n "$global_override_seconds" ]] && should_apply_global_override_for_sketch "$current_sketch" "$one_based_index"; then
    effective="$global_override_seconds"
    source="global_override"
  fi

  local interactive_override_seconds=""
  interactive_override_seconds="$(interactive_override_seconds_for_sketch "$current_sketch")"
  if [[ -n "$interactive_override_seconds" ]]; then
    effective="$interactive_override_seconds"
    source="interactive_override"
  fi

  echo "${effective}|${source}"
}

print_playlist_plan() {
  # PRE:
  # - SKETCHES has final run selection in execution order.
  # - override state already validated.
  # POST:
  # - emits a human-readable plan with hold/timeout values and sources.
  # - does not mutate runtime selection state.
  echo "[+] Resolved playlist plan:"
  local i
  for i in "${!SKETCHES[@]}"; do
    local current_sketch="${SKETCHES[$i]}"
    local base_name
    base_name="$(basename "$current_sketch")"

    local hold_base="${DEFAULT_HOLD_SECONDS}"
    local hold_base_source="default"
    if [[ "$i" -lt "${#HOLD_SECONDS[@]}" ]]; then
      hold_base="${HOLD_SECONDS[$i]}"
      hold_base_source="array"
    fi
    local hold_pair=""
    hold_pair="$(resolve_effective_duration "$current_sketch" "$((i + 1))" "$hold_base" "$hold_base_source")"
    local hold="${hold_pair%%|*}"
    local hold_source="${hold_pair#*|}"

    local timeout_base="${DEFAULT_DONE_TIMEOUT_SECONDS}"
    local timeout_base_source="default_done_timeout"
    if [[ "$i" -lt "${#DONE_TIMEOUT_SECONDS[@]}" ]]; then
      timeout_base="${DONE_TIMEOUT_SECONDS[$i]}"
      timeout_base_source="done_timeout_array"
    elif [[ "$i" -lt "${#HOLD_SECONDS[@]}" ]]; then
      timeout_base="${HOLD_SECONDS[$i]}"
      timeout_base_source="hold_array_fallback"
    fi
    local timeout_pair=""
    timeout_pair="$(resolve_effective_duration "$current_sketch" "$((i + 1))" "$timeout_base" "$timeout_base_source")"
    local timeout="${timeout_pair%%|*}"
    local timeout_source="${timeout_pair#*|}"

    local timer_tag=""
    if is_afoqt_timer_sketch "$current_sketch"; then
      timer_tag=" timer"
    fi
    echo "  - [$((i + 1))] ${base_name}${timer_tag}"
    echo "    hold: ${hold}s (${hold_source})"
    echo "    token-timeout: ${timeout}s (${timeout_source})"
  done
}

main() {
  # Main playlist engine:
  # 1) upload sketch
  # 2) wait for token or timeout (or skip)
  # 3) optionally run serial weather/time segment
  # 4) repeat by cycle configuration
  need_cmd "$ARDUINO_CLI"
  trap cleanup_background_jobs EXIT
  parse_args "$@"
  if [[ "$ENABLE_SERIAL_FEED" == "true" ]]; then
    resolve_serial_feed_sketch
  else
    SERIAL_FEED_SKETCH_PATH=""
  fi

  if [[ "$AUTO_DISCOVER_SKETCHES" == "true" ]]; then
    discover_sketches
  fi
  if [[ "$INTERACTIVE_PLAYLIST" == "true" && "$INTERACTIVE_SELECTION_APPLIED" != "true" ]]; then
    apply_interactive_playlist_selection
  fi

  if [[ "$AUTO_DISCOVER_SKETCHES" != "true" && ${#SKETCHES[@]} -ne ${#HOLD_SECONDS[@]} ]]; then
    echo "[!] SKETCHES and HOLD_SECONDS length mismatch; using DEFAULT_HOLD_SECONDS=${DEFAULT_HOLD_SECONDS}s"
  fi

  local global_override_seconds=""
  local override_mode="none"
  local override_index_1_based=0
  local override_basename=""
  if [[ -n "$DURATION_OVERRIDE_HHMMSS" ]]; then
    global_override_seconds="$(hhmmss_to_seconds "$DURATION_OVERRIDE_HHMMSS")"
    if [[ -z "$global_override_seconds" ]]; then
      echo "[!] Invalid --duration-override-hhmmss value: $DURATION_OVERRIDE_HHMMSS"
      echo "[!] Expected HHMMSS with MM/SS <= 59, e.g. 003000"
      return 2
    fi
    if [[ -n "$OVERRIDE_INDEX" && -n "$OVERRIDE_SKETCH" ]]; then
      echo "[!] Use either --override-index or --override-sketch, not both."
      return 2
    fi
    if [[ -n "$OVERRIDE_INDEX" ]]; then
      override_mode="index"
      override_index_1_based="$OVERRIDE_INDEX"
      echo "[+] Duration override active for index ${override_index_1_based}: ${DURATION_OVERRIDE_HHMMSS} (${global_override_seconds}s)"
    elif [[ -n "$OVERRIDE_SKETCH" ]]; then
      override_mode="sketch"
      override_basename="$(basename "$OVERRIDE_SKETCH")"
      echo "[+] Duration override active for sketch ${override_basename}: ${DURATION_OVERRIDE_HHMMSS} (${global_override_seconds}s)"
    else
      override_mode="global"
      echo "[+] Global duration override active: ${DURATION_OVERRIDE_HHMMSS} (${global_override_seconds}s)"
    fi
  fi
  if [[ "$PRINT_PLAYLIST_PLAN" == "true" ]]; then
    print_playlist_plan
    return 0
  fi

  local cycle=0
  while true; do
    # PRE: runtime config and overrides are finalized.
    # POST: one full cycle processes current sketch list in order.
    cleanup_background_jobs
    force_release_port_if_owned_by_helpers
    wait_for_port_free "$PORT_WAIT_TIMEOUT_SECONDS" >/dev/null 2>&1 || true
    refresh_discovery_if_enabled
    cycle=$((cycle + 1))
    echo "[+] Starting playlist cycle ${cycle}"
    echo "[+] Tip: press Space to skip to next item"

    for i in "${!SKETCHES[@]}"; do
      # PRE: i references a valid item in SKETCHES for this cycle snapshot.
      # POST:
      # - sketch is uploaded (or skipped/continued on recoverable conditions),
      # - one of hold/token/feed paths is executed before advancing.
      local current_sketch="${SKETCHES[$i]}"
      if [[ ! -f "$current_sketch" ]]; then
        if [[ "$AUTO_DISCOVER_SKETCHES" == "true" ]]; then
          echo "[!] Sketch path changed or removed: $current_sketch"
          echo "[+] Refreshing discovery and continuing"
          refresh_discovery_if_enabled
          continue
        fi
        echo "[!] Sketch file missing: $current_sketch"
        return 1
      fi
      upload_sketch "$current_sketch"
      sleep "$UPLOAD_SETTLE_SECONDS"

      local hold_base="${DEFAULT_HOLD_SECONDS}"
      local hold_base_source="default"
      if [[ "$i" -lt "${#HOLD_SECONDS[@]}" ]]; then
        hold_base="${HOLD_SECONDS[$i]}"
        hold_base_source="array"
      fi
      local hold_pair=""
      hold_pair="$(resolve_effective_duration "$current_sketch" "$((i + 1))" "$hold_base" "$hold_base_source")"
      local hold="${hold_pair%%|*}"
      local hold_source="${hold_pair#*|}"

      if [[ "$ENABLE_SERIAL_FEED" == "true" && "$current_sketch" == "$SERIAL_FEED_SKETCH_PATH" ]]; then
        echo "[+] Running serial weather/time feed for ${hold}s (source: ${hold_source})"
        run_serial_feed "$hold"
        continue
      fi

      send_timer_start_if_applicable "$current_sketch" "$hold"

      if [[ "$WAIT_FOR_DONE" == "true" ]]; then
        local timeout_base="${DEFAULT_DONE_TIMEOUT_SECONDS}"
        local timeout_base_source="default_done_timeout"
        if [[ "$i" -lt "${#DONE_TIMEOUT_SECONDS[@]}" ]]; then
          timeout_base="${DONE_TIMEOUT_SECONDS[$i]}"
          timeout_base_source="done_timeout_array"
        elif [[ "$i" -lt "${#HOLD_SECONDS[@]}" ]]; then
          timeout_base="${HOLD_SECONDS[$i]}"
          timeout_base_source="hold_array_fallback"
        fi
        local timeout_pair=""
        timeout_pair="$(resolve_effective_duration "$current_sketch" "$((i + 1))" "$timeout_base" "$timeout_base_source")"
        local timeout="${timeout_pair%%|*}"
        local timeout_source="${timeout_pair#*|}"
        echo "[+] Waiting for token '${DONE_TOKEN}' (timeout: ${timeout}s, source: ${timeout_source})"
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
        echo "[+] Running for ${hold}s (source: ${hold_source})"
        if sleep_with_skip "${hold}"; then
          echo "[+] Space pressed: skipping to next sketch"
        fi
      fi
    done

    if [[ "$PLAYLIST_CYCLES" -gt 0 && "$cycle" -ge "$PLAYLIST_CYCLES" ]]; then
      break
    fi
  done

  echo "[+] Playlist complete"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
