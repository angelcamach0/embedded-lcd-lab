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
2. `_TTT` (`mss`) suffix is useful as per-sketch runtime metadata.
3. In token mode, `_TTT` works well as a per-sketch timeout override.
4. Auto-discovery default reduces maintenance when adding/removing sketches.

## Project/process

1. Good docs save significant debugging time for wiring and setup.
2. Public repo readiness needs explicit files:
   - license
   - privacy notes
   - disclaimer
   - contribution/security guidance
3. Clear acceptance criteria keep future phases focused.

## See also

1. `REPLICATION_REQUIREMENTS.md` for setup and dependency baseline
2. `wiring.md` for the tested LCD wiring map
3. `FUTURE_IDEAS_AND_IMPLEMENTATION_PLAN.md` for next-phase architecture
4. `INDEX.md` for full doc navigation
