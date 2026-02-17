# Phase 1 Task Checklist (Master Offline Firmware)

This checklist is for Phase 1 only: move from host-driven playlist uploads to one single firmware that rotates scenes internally.

## Scope
- In scope:
  - One uploaded sketch that runs all scenes.
  - Scene scheduler/state machine.
  - No reflash between scenes.
- Out of scope (later phases):
  - RTC module integration.
  - EEPROM forecast cache.
  - Offline weather provisioning.

## Definition Of Done (Phase 1)
- [ ] Arduino runs wakeup -> matrix -> weather scene loop from one firmware.
- [ ] `run_playlist.sh` is not required for scene transitions.
- [ ] Scene switching works by timeout and/or scene done-token.
- [ ] No serial exceptions caused by repeated reflash during normal runtime.

## Task Breakdown

## 1) Create master sketch structure
- [ ] Create folder: `src/lcd_master_offline/`
- [ ] Create files:
  - [ ] `lcd_master_offline.ino`
  - [ ] `scene_wakeup.h`
  - [ ] `scene_wakeup.cpp`
  - [ ] `scene_matrix.h`
  - [ ] `scene_matrix.cpp`
  - [ ] `scene_weather.h`
  - [ ] `scene_weather.cpp`
  - [ ] `scene_types.h` (shared enums/interfaces)

## 2) Define common scene interface
- [ ] Add interface methods for each scene:
  - [ ] `begin(uint32_t nowMs)`
  - [ ] `tick(uint32_t nowMs)`
  - [ ] `isDone(uint32_t nowMs)`
  - [ ] `reset()`
- [ ] Ensure each scene is non-blocking (no long `delay()` loops).

## 3) Implement scheduler in `lcd_master_offline.ino`
- [ ] Add scene enum (WAKEUP, MATRIX, WEATHER).
- [ ] Keep current scene index and scene start timestamp.
- [ ] Call current scene `tick()` every `loop()`.
- [ ] Advance scene when:
  - [ ] `isDone(...) == true`, or
  - [ ] safety timeout exceeded.
- [ ] On transition:
  - [ ] clear LCD
  - [ ] call next scene `begin(...)`

## 4) Port existing behaviors into scenes
- [ ] Move wakeup reveal logic into `scene_wakeup.cpp`.
- [ ] Move matrix rain logic into `scene_matrix.cpp`.
- [ ] Move weather/time render logic into `scene_weather.cpp`.
- [ ] Replace host token usage (`PLAYLIST_DONE`) with internal `isDone()`.

## 5) Add simple configuration constants
- [ ] Add tunables in one place (top of `.ino` or `config.h`):
  - [ ] wakeup duration
  - [ ] matrix duration
  - [ ] weather duration
  - [ ] frame/update intervals
- [ ] Keep defaults stable for first test pass.

## 6) Build + flash + test loop
- [ ] Compile:
  - [ ] `arduino-cli compile --fqbn arduino:avr:uno src/lcd_master_offline`
- [ ] Upload:
  - [ ] `arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:avr:uno src/lcd_master_offline`
- [ ] Runtime verification:
  - [ ] Observe at least 3 full cycles without host interaction.
  - [ ] Confirm scene order and transitions are correct.
  - [ ] Confirm no startup glitch worse than current baseline.

## 7) Regression checks
- [ ] Existing standalone sketches still compile:
  - [ ] [`src/playlist/03_lcd_wakeup_reveal_030.ino`](src/playlist/03_lcd_wakeup_reveal_030.ino)
  - [ ] [`src/playlist/02_lcd_matrix_rain_010.ino`](src/playlist/02_lcd_matrix_rain_010.ino)
  - [ ] [`src/playlist/04_lcd_city_datetime_temp_feed_100.ino`](src/playlist/04_lcd_city_datetime_temp_feed_100.ino)
- [ ] README update notes Phase 1 architecture and usage.

## Risks To Watch
- [ ] RAM pressure on Uno (2 KB SRAM) after combining all scenes.
- [ ] Blocking delays causing stutter or missed transitions.
- [ ] LCD flicker on scene switch (clear/redraw timing).

## If RAM Gets Tight
- [ ] Replace dynamic strings with fixed char arrays (`PROGMEM` where possible).
- [ ] Reduce temporary buffers and matrix state arrays.
- [ ] Lower refresh frequency and simplify effect density.

## Execution Notes
- Owner:
- Start date:
- Target complete date:
- Current status: `Not Started`
- Last update:

