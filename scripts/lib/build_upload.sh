#!/usr/bin/env bash

# Build/cache/upload helpers for Arduino sketch transitions.
# These functions rely on shared globals supplied by run_playlist.sh.

build_cache_key() {
  # PRE: sketch_input points to a sketch file or directory.
  # POST: echoes stable cache key including board/libs/source fingerprints.
  local sketch_input="$1"
  local src_hash="unknown"
  local libs_hash="none"
  if [[ -f "$sketch_input" ]]; then
    src_hash="$(sha1sum "$sketch_input" | awk '{print $1}')"
  elif [[ -d "$sketch_input" ]]; then
    src_hash="$(find "$sketch_input" -type f -print0 | sort -z | xargs -0 sha1sum 2>/dev/null | sha1sum | awk '{print $1}')"
  fi

  # Include local library contents so helper/library edits invalidate cache.
  if [[ -d "$LOCAL_LIBRARIES_DIR" ]]; then
    libs_hash="$(find "$LOCAL_LIBRARIES_DIR" -type f -print0 | sort -z | xargs -0 sha1sum 2>/dev/null | sha1sum | awk '{print $1}')"
  fi

  printf '%s' "${BOARD_FQBN}|${LOCAL_LIBRARIES_DIR}|${libs_hash}|${sketch_input}|${src_hash}" | sha1sum | awk '{print $1}'
}

prepare_sketch_dir() {
  # PRE: sketch_input is a sketch file path (.ino) or sketch directory.
  # POST: echoes "<sketch_dir>|<cleanup_dir>" for arduino-cli compile input.
  local sketch_input="$1"
  local sketch_dir="$sketch_input"
  local cleanup_dir=""
  local stem=""

  if [[ -f "$sketch_input" && "$sketch_input" == *.ino ]]; then
    stem="$(basename "${sketch_input%.ino}")"
    cleanup_dir="$(mktemp -d)"
    sketch_dir="$cleanup_dir/$stem"
    mkdir -p "$sketch_dir"
    cp "$sketch_input" "$sketch_dir/$stem.ino"
  fi

  printf '%s|%s\n' "$sketch_dir" "$cleanup_dir"
}

compiled_build_ready() {
  # PRE: build_dir is a build artifact directory path.
  # POST: returns 0 when expected .hex artifact exists, non-zero otherwise.
  local build_dir="$1"
  compgen -G "$build_dir/*.hex" >/dev/null
}

compile_for_upload() {
  # PRE:
  # - ARDUINO_CLI, BOARD_FQBN, LOCAL_LIBRARIES_DIR, BUILD_CACHE_ROOT configured.
  # POST:
  # - echoes build directory containing upload artifacts.
  local sketch_input="$1"
  local key build_dir prepared sketch_dir cleanup_dir
  key="$(build_cache_key "$sketch_input")"
  build_dir="$BUILD_CACHE_ROOT/$key"

  mkdir -p "$BUILD_CACHE_ROOT"
  if [[ "$PRECOMPILE_ONCE" == "true" ]] && compiled_build_ready "$build_dir"; then
    echo "$build_dir"
    return 0
  fi

  prepared="$(prepare_sketch_dir "$sketch_input")"
  IFS='|' read -r sketch_dir cleanup_dir <<< "$prepared"

  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  "$ARDUINO_CLI" compile \
    --libraries "$LOCAL_LIBRARIES_DIR" \
    --build-path "$build_dir" \
    --fqbn "$BOARD_FQBN" \
    "$sketch_dir" \
    1>&2

  if [[ -n "$cleanup_dir" ]]; then
    rm -rf "$cleanup_dir"
  fi

  echo "$build_dir"
}

upload_sketch() {
  # PRE:
  # - sketch_input exists.
  # - port helper functions and cleanup_background_jobs are available.
  # POST:
  # - returns 0 on successful upload.
  # - returns non-zero after bounded retries.
  local sketch_input="$1"
  local build_dir=""

  cleanup_background_jobs
  force_release_port_if_owned_by_helpers
  sleep 0.2
  if ! wait_for_port_free "$PORT_WAIT_TIMEOUT_SECONDS"; then
    cleanup_background_jobs
    force_release_port_if_owned_by_helpers
  fi
  echo "[+] Uploading: $sketch_input"
  build_dir="$(compile_for_upload "$sketch_input")"

  local attempt
  for attempt in 1 2 3; do
    if ! wait_for_port_free "$PORT_WAIT_TIMEOUT_SECONDS"; then
      cleanup_background_jobs
      force_release_port_if_owned_by_helpers
      sleep 0.7
      continue
    fi

    if "$ARDUINO_CLI" upload -p "$PORT" --fqbn "$BOARD_FQBN" --input-dir "$build_dir"; then
      return 0
    fi
    echo "[!] Upload attempt ${attempt} failed; retrying shortly..."
    cleanup_background_jobs
    force_release_port_if_owned_by_helpers
    sleep 1.2
  done
  echo "[!] Upload failed after retries: $sketch_input"
  return 1
}
