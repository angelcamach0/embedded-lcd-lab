# Lessons Learned

This log captures practical lessons discovered while building this project.

## Hardware and wiring

1. LCD backlight cathode (`K`, pin 16) must be connected to GND or the display may appear to "die" after startup.
2. Missing/incorrect contrast wiring on `VO` can make text invisible even when code is correct.
3. Either Arduino GND pin works; grounds are common.
4. A potentiometer for `VO` makes troubleshooting much easier than tying `VO` directly to GND.

## Arduino and toolchain

1. Sketch folder naming matters for `arduino-cli` (folder-based sketch structure is more reliable).
2. File-based playlist entries still work by staging each `.ino` into a temporary sketch folder before compile/upload.
3. Install board core and libraries explicitly to avoid first-run compile failures.
4. Serial port permissions (`dialout`) are a common Linux blocker.
5. Snap-packaged tooling may have extra device access constraints.

## Serial upload/runtime behavior

1. Uploading sketches repeatedly can race with serial watchers, causing `programmer is not responding` or port-busy errors.
2. Cleanup of background serial processes is required before upload retries.
3. UNO resets when serial opens; short post-open delays improve stability.
4. Skip controls and cooldowns reduce user friction during playlist development.
5. If Arduino IDE Serial Monitor is open, uploads and token watchers can conflict immediately.
6. Space-skip during active serial watch/upload transitions needs brief cooldown to avoid rapid port churn.

## Firmware implementation choices

1. Fixed-size buffers are safer than dynamic `String` for small SRAM targets.
2. Rendering full LCD rows each update prevents leftover/stale characters.
3. ASCII filtering avoids weird glyphs from unsupported character sets.
4. Non-blocking scene/state-machine architecture is preferred for future offline mode.

## Weather/data pipeline

1. Weather providers can timeout intermittently; fallback logic is necessary.
2. Fetch once, then convert C/F locally to reduce network dependency.
3. Geocoding can enrich display (city/state tag), but should fail gracefully.
4. Weather segment sketch path should be resolved dynamically by pattern, not hardcoded to one filename.

## Playlist/discovery behavior

1. Numeric prefix naming (`NN_`) keeps playlist order predictable for contributors.
2. `_HHMMSS` suffix is a clearer per-sketch runtime metadata format than legacy `_TTT`.
3. In token mode, duration suffix works as a per-sketch timeout override.
4. Auto-discovery default reduces maintenance when adding/removing sketches.

## Project/process

1. Good docs save significant debugging time for wiring and setup.
2. Public repo readiness needs explicit files:
   - license
   - privacy notes
   - disclaimer
   - contribution/security guidance
3. Clear acceptance criteria keep future phases focused.

## Resolved issue log (recent)

1. Port-busy failures after skip transitions
   - Root cause: serial helper processes occasionally survived long enough to block next upload.
   - Resolution: added aggressive helper cleanup + port-drain waits + stale helper PID release before uploads.
2. Runtime sketch rename crashes
   - Root cause: auto-discovered playlist paths were cached and not refreshed.
   - Resolution: re-discover sketches each cycle and recover when a path disappears mid-run.
3. Duration naming ambiguity (`_TTT`)
   - Root cause: legacy `mss` parsing led to unexpected behavior for values like `_060`.
   - Resolution: introduced preferred `_HHMMSS` duration format and kept legacy compatibility.
4. Broken docs links
   - Root cause: incorrect relative-path rewrite inside nested docs folders.
   - Resolution: corrected path prefixes and validated all internal markdown links.

## What this proves to recruiters

1. Embedded systems implementation
   - Example: built and debugged direct 16x2 LCD wiring, including `VO` contrast and `A/K` backlight behavior (see `wiring.md` and `src/playlist/01_lcd_baseline_010.ino`).
2. Automation and tooling
   - Example: created playlist automation around `arduino-cli` with compile/upload/run flow in `scripts/run_playlist.sh` and `scripts/compile_playlist_sketches.sh`.
3. Cross-layer systems design
   - Example: coordinated host scripts plus firmware via a defined serial contract (`SERIAL_PROTOCOL.md`, `scripts/lib/serial_feed.py`, `src/playlist/04_lcd_city_datetime_temp_feed_100.ino`).
4. Debugging and operational reliability
   - Example: handled port contention, watcher cleanup, reset timing, retry logic, and skip control behavior in runtime loops (`scripts/run_playlist.sh`, `TROUBLESHOOTING.md`).
5. Firmware quality decisions
   - Example: used fixed buffers, full-row rendering, and sanitization to avoid stale characters and LCD glyph issues (`src/common/lcd_shared/src/lcd_shared.h`, serial feed sketch).
6. Extensible architecture
   - Example: implemented auto-discovery and naming conventions (`NN_`, `_HHMMSS`) so users can drop in sketches without changing core logic (`DROP_IN_SKETCHES.md`).
7. Reproducibility and developer experience
   - Example: documented dependencies, Linux permission setup, and run validation steps (`REPLICATION_REQUIREMENTS.md`, `INDEX.md`).
8. Security/privacy awareness
   - Example: separated privacy/disclaimer/security expectations and limited runtime data flow to explicit serial payloads (`PRIVACY.md`, `DISCLAIMER.md`, `SECURITY.md`, `SERIAL_PROTOCOL.md`).
9. Collaboration readiness
   - Example: maintained structured docs, contribution guidance, and repo hygiene for external users and reviewers (`CONTRIBUTING.md`, top-level project docs).

## See also

1. [`REPLICATION_REQUIREMENTS.md`](REPLICATION_REQUIREMENTS.md) for setup and dependency baseline
2. [`wiring.md`](wiring.md) for the tested LCD wiring map
3. [`FUTURE_IDEAS_AND_IMPLEMENTATION_PLAN.md`](FUTURE_IDEAS_AND_IMPLEMENTATION_PLAN.md) for next-phase architecture
4. [`INDEX.md`](INDEX.md) for full doc navigation
