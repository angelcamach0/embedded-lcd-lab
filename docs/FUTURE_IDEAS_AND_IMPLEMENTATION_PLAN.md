# Future Ideas And Implementation Plan

This document tracks features discussed but not implemented yet, plus the intended implementation approach.

## 1) Offline Mode (No Laptop Connected)

### Goal
Run playlist + time + weather behavior after unplugging USB (for example on a battery bank).

### Why current setup is limited
- Current playlist logic is script-driven (`run_playlist.sh`), so it depends on a connected computer.
- Re-uploading different sketches resets the MCU and loses runtime state.

### Proposed approach
- Build one master firmware (single sketch project with multiple source files).
- Convert each effect into a scene/state-machine:
1. wakeup reveal scene
2. matrix rain scene
3. weather/time scene
- Use a scheduler in `loop()` to switch scenes internally without reflashing.

### Implementation outline
1. Create `src/lcd_master_offline/` with:
- `lcd_master_offline.ino` (entry/scheduler)
- `scene_wakeup.*`
- `scene_matrix.*`
- `scene_weather.*`
- `services_clock.*`
- `services_forecast.*`
2. Add scene interface:
- `begin()`
- `tick(now_ms)`
- `isDone()`
3. Scheduler rotates scenes by duration or done-flag.

## 2) Stable Timekeeping Offline

### Goal
Keep correct date/time while disconnected and powered by battery.

### Recommended hardware
- DS3231 RTC module + coin cell backup.

### Fallback
- `millis()`-based relative time (drifts and resets on power cycle).

### Implementation outline
1. Add RTC service wrapper:
- `initClock()`
- `getDateTime()`
- `setDateTime()`
2. Add compile-time switch:
- `USE_RTC true/false`
3. Add one-time sync command from script over serial.

## 3) Preloaded 24-Hour Forecast Cache

### Goal
Fetch forecast once while online, then use hourly values offline all day.

### Storage plan
- Store forecast in EEPROM:
1. version byte
2. start timestamp
3. 24 hourly temps (prefer tenths of degree as `int16_t`)
4. location label/tag
5. CRC/checksum

### Implementation outline
1. Add host script `scripts/provision_forecast.py`:
- fetch geocode + hourly forecast
- send compact payload over serial
2. Add firmware serial provisioning command parser:
- `SET_TIME|...`
- `SET_FORECAST|...`
3. On boot:
- verify checksum
- load forecast if valid
- otherwise show `Wx N/A`.

## 4) Unified Provisioning Flow

### Goal
One command to prepare device for offline run.

### Proposed CLI flow
1. Upload master offline sketch.
2. Push time sync.
3. Push location + 24-hour forecast.
4. Verify acknowledgement/status.

### Candidate command
```bash
./scripts/provision_offline_mode.sh --port /dev/ttyACM0 --location "El Paso" --lat 31.7619 --lon -106.4850
```

## 5) Script UX Improvements

### Ideas
1. Add `--mode online|offline-provision|offline-run` argument support.
2. Add `.env` file support for persistent defaults.
3. Add structured logs (`logs/playlist-YYYYMMDD.log`).
4. Add retry/backoff metrics in output summary.

## 6) Hardware Robustness Improvements

### Ideas
1. Add contrast potentiometer (`VO`) in standard wiring reference.
2. Add optional button input for local scene skip (offline mode).
3. Add optional buzzer cue at scene transition.

## 7) Nice-To-Have Future Integrations

### Raspberry Pi track (separate future project)
1. Use Pi for richer display and media rendering.
2. Keep Arduino as sensor/actuator sidecar over serial/I2C.
3. Build a bridge protocol for weather/time/scene commands.

## 8) Suggested Build Order

1. Master single-firmware scheduler (no reflashing between scenes).
2. RTC service integration (`DS3231`).
3. EEPROM forecast cache + checksum.
4. Provisioning script + serial protocol.
5. Offline test cycle on battery bank.

## 9) Acceptance Criteria (Offline Milestone)

Offline mode is complete when all are true:
1. Device boots with no USB host.
2. Date/time is correct after power cycle (with RTC battery).
3. Playlist runs all scenes continuously.
4. Weather display uses preloaded hourly data.
5. No host script required during runtime.
