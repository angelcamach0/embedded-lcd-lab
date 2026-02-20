# Embedded LCD Lab

We built a plug-and-play Arduino LCD display system that lets you run a rotating playlist of `.ino` scenes with minimal setup friction.
It was built for makers, students, and tinkerers who want something more powerful than a single demo sketch, while still staying easy to wire, run, and extend.

## Why this is cool

1. Comes with preloaded scenes out of the box (`baseline`, `matrix rain`, `wakeup reveal`, `city/date/time/temp feed`)
2. Host playlist runner automatically cycles sketches for you
3. Drop-in workflow: add your own `.ino` files to [`src/playlist/`](src/playlist/) and they get picked up automatically
4. Naming conventions control behavior (order + timing) without rewriting orchestration logic
5. Space skip, loop control, token/timer modes, and weather feed support are already built in

Want the naming convention + drop-in rules?
1. Click here: [`docs/DROP_IN_SKETCHES.md`](docs/DROP_IN_SKETCHES.md)

## Start Here (Recommended)

If you only want to get it running quickly, follow this order:

1. Hardware wiring: [`docs/wiring.md`](docs/wiring.md)
2. Environment + dependencies: [`docs/REPLICATION_REQUIREMENTS.md`](docs/REPLICATION_REQUIREMENTS.md)
3. Run it: [`scripts/run_playlist.sh`](scripts/run_playlist.sh)
4. If something fails: [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)

## Hardware

1. Arduino Uno (or compatible board with `arduino:avr:uno` profile)
2. HD44780-compatible 16x2 LCD (16-pin)
3. Breadboard + jumper wires
4. Recommended: 10k potentiometer for LCD contrast (`VO`)
5. Recommended: ~220 ohm resistor for LCD backlight anode (`A`)

See [`docs/wiring.md`](docs/wiring.md) for the tested pin map.

## Software requirements

1. `arduino-cli`
2. Python 3
3. Python module `pyserial`
4. Optional internet access (only needed for live weather fetch)

Detailed install + replication checklist:
- [`docs/REPLICATION_REQUIREMENTS.md`](docs/REPLICATION_REQUIREMENTS.md)

## Quick start

```bash
# HTTPS
git clone https://github.com/angelcamach0/embedded-lcd-lab.git
# SSH
git clone git@github.com:angelcamach0/embedded-lcd-lab.git

cd embedded-lcd-lab
cp .env.example .env
python3 -m pip install --user pyserial
arduino-cli core update-index
arduino-cli core install arduino:avr
arduino-cli lib update-index
arduino-cli lib install LiquidCrystal
```

Linux serial permissions (if upload fails with `Permission denied`):

```bash
sudo usermod -aG dialout "$USER"
newgrp dialout
```

## Run playlist

```bash
cd scripts
./run_playlist.sh
```

Examples with flags:

```bash
./run_playlist.sh --port /dev/ttyACM0 --weather-lat 31.7619 --weather-lon -106.4850
./run_playlist.sh --weather-ip 8.8.8.8
./run_playlist.sh --precompile-once true
./run_playlist.sh --upload-settle-seconds 0.9
./run_playlist.sh --auto-discover true --wait-for-done false --cycles 1
./run_playlist.sh --enable-legacy-ttt-duration true
./run_playlist.sh --enable-timer-start-command true
./run_playlist.sh --duration-override-hhmmss 003000
```

Default runtime behavior (no flags):

1. Auto-discovery enabled (`AUTO_DISCOVER_SKETCHES=true`)
2. Timed mode enabled (`WAIT_FOR_DONE=false`)
3. Infinite cycles (`PLAYLIST_CYCLES=0`)

`PLAYLIST_CYCLES` / `--cycles` behavior:

1. `0` means infinite loop (default).
2. `1` means run one full cycle and stop.
3. `N` means run N full cycles and stop.

Per-sketch duration naming (optional):

1. Full recommended pattern: `NN_name_HHMMSS.ino`.
2. `NN_` controls playlist order (sequence):
   - Lower `NN` plays first.
   - If two files share the same `NN`, they are ordered alphabetically by `name`.
3. `HHMMSS` controls per-sketch runtime (24-hour style duration block).
4. Examples:
   - `05_custom_scene_000010.ino` -> 10 seconds
   - `05_custom_scene_000100.ino` -> 1 minute
   - `05_custom_scene_013000.ino` -> 1 hour 30 minutes
5. If `WAIT_FOR_DONE=false`, this drives hold duration directly.
6. If `WAIT_FOR_DONE=true`, this value is used as token wait timeout.
7. Legacy `_TTT` is disabled by default.
8. To enable legacy `_TTT`, run with `--enable-legacy-ttt-duration true` (or set `ENABLE_LEGACY_TTT_DURATION=true` in `.env`).
9. Optional global runtime override: `--duration-override-hhmmss HHMMSS` (applies to all sketches).

## First-run success checklist

1. LCD shows output from `01_lcd_baseline_000010.ino`.
2. Playlist transitions across sketches.
3. `Space` skips to next stage.
4. Serial weather/date sketch updates when enabled.

## Compile sketches manually

```bash
./scripts/compile_playlist_sketches.sh
```

CI also compiles all sketches on push/PR:
- [`.github/workflows/compile-sketches.yml`](.github/workflows/compile-sketches.yml)

## Keyboard controls

1. Press `Space` to skip to the next sketch.
2. Press `Space` during weather feed to skip weather mode early.
3. Space skip overrides normal token/time waits and advances immediately.

## Weather/time behavior

1. Weather is fetched once per weather segment.
2. Location resolution priority:
   - `WEATHER_LAT/WEATHER_LON` if set
   - explicit `--weather-ip` / `WEATHER_IP` if set
   - auto-detect current public IP location
   - fallback to `WEATHER_LOCATION`
   Note: public-IP geolocation is approximate and may reflect VPN/ISP egress location.
3. Celsius/Fahrenheit toggles every 5 seconds from one fetched value.
4. Top row alternates every 5 seconds:
   - `HH:MM:SS`
   - `Mon DD YYYY`
5. Top-right 2 characters show region tag (US state abbreviation when available, otherwise country code/default).

## Configuration

Main runtime config is at the top of [`scripts/run_playlist.sh`](scripts/run_playlist.sh):

1. `PORT`, `BOARD_FQBN`, `ARDUINO_CLI`
2. `LOCAL_LIBRARIES_DIR`
3. `SKETCHES`, `HOLD_SECONDS`, `AUTO_DISCOVER_SKETCHES`
4. `WAIT_FOR_DONE`, `DONE_TOKEN`, `DONE_TIMEOUT_SECONDS`
5. `ENABLE_SERIAL_FEED`, `SERIAL_FEED_SECONDS`
6. `WEATHER_LOCATION`, `WEATHER_LAT`, `WEATHER_LON`, `WEATHER_IP`
7. `PLAYLIST_CYCLES`
8. `POST_SKIP_COOLDOWN_SECONDS`, `PORT_WAIT_TIMEOUT_SECONDS`
9. `UPLOAD_SETTLE_SECONDS`
10. `PRECOMPILE_ONCE`, `BUILD_CACHE_ROOT`
11. `ENABLE_LEGACY_TTT_DURATION`
12. `ENABLE_TIMER_START_COMMAND`
12. `DURATION_OVERRIDE_HHMMSS`

Preferred config path for users:
1. Copy [`.env.example`](.env.example) to `.env`
2. Edit `.env` values instead of changing script defaults
3. Optional: launch with custom env file:
   - `ENV_FILE=/path/to/custom.env ./scripts/run_playlist.sh`

## Privacy and security notes

1. This repo does not contain API keys or authentication secrets.
2. The weather feature sends either:
   - configured coordinates (`WEATHER_LAT/WEATHER_LON`), or
   - configured/auto public IP for geolocation (`WEATHER_IP` or auto-IP), or
   - configured location text (`WEATHER_LOCATION`)
   to public weather/geocoding endpoints.
3. If you do not want any outbound network calls, disable serial weather feed in `run_playlist.sh`:
   - set `ENABLE_SERIAL_FEED=false`

See [`PRIVACY.md`](PRIVACY.md) for full details.

## Known limitations

1. Rapidly pressing `Space` across uploads can still trigger transient serial port contention on some systems.
2. Public-IP geolocation is approximate and can reflect VPN, carrier NAT, or ISP egress points.
3. Weather APIs can time out; script falls back to alternate providers and `N/A` as needed.
4. Playlist transitions require sketch upload each time, so small upload latency is expected on AVR boards.

## Optional Deep Dives

Use these only if you want more detail:

1. [`docs/INDEX.md`](docs/INDEX.md): full docs map
2. [`docs/SERIAL_PROTOCOL.md`](docs/SERIAL_PROTOCOL.md): host/firmware payload contract
3. [`docs/animation-flow.md`](docs/animation-flow.md): reveal animation internals
4. [`docs/DROP_IN_SKETCHES.md`](docs/DROP_IN_SKETCHES.md): adding custom playlist sketches
5. [`docs/LESSONS_LEARNED.md`](docs/LESSONS_LEARNED.md): practical pitfalls from development
6. [`docs/FUTURE_IDEAS_AND_IMPLEMENTATION_PLAN.md`](docs/FUTURE_IDEAS_AND_IMPLEMENTATION_PLAN.md): roadmap ideas
7. [`docs/WEB_TRIGGER_IMPLEMENTATION_DRAFT.md`](docs/WEB_TRIGGER_IMPLEMENTATION_DRAFT.md): early draft notes
8. [`docs/diagrams/README.md`](docs/diagrams/README.md): architecture diagram index
9. [`docs/codeflows/README.md`](docs/codeflows/README.md): per-file behavior maps

## Safety and liability

This project is for educational use. You are responsible for wiring, power limits, and safe operation of your hardware. See [`DISCLAIMER.md`](DISCLAIMER.md).

## Repo layout

1. [`src/playlist/`](src/playlist/) runtime playlist sketches (`.ino` files)
2. [`src/common/lcd_shared/`](src/common/lcd_shared/) local reusable Arduino library for shared LCD helpers
3. [`scripts/`](scripts/) host automation
4. [`scripts/lib/`](scripts/lib/) Python helpers used by playlist/weather flow
5. [`scripts/compile_playlist_sketches.sh`](scripts/compile_playlist_sketches.sh) compile helper for file-based playlist structure
6. [`.env.example`](.env.example) sample runtime configuration values
7. [`docs/`](docs/) design notes, wiring, and plans
8. [`docs/diagrams/`](docs/diagrams/) architecture diagrams
9. [`docs/codeflows/`](docs/codeflows/) per-code-file behavior maps
10. [`docs/INDEX.md`](docs/INDEX.md) docs index and suggested reading path
11. [`docs/REPLICATION_REQUIREMENTS.md`](docs/REPLICATION_REQUIREMENTS.md) full dependency/setup requirements
12. [`docs/LESSONS_LEARNED.md`](docs/LESSONS_LEARNED.md) project learnings and pitfalls
13. [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) quick fixes for common setup/runtime issues
14. [`docs/SERIAL_PROTOCOL.md`](docs/SERIAL_PROTOCOL.md) serial payload/token contract reference
15. [`docs/DROP_IN_SKETCHES.md`](docs/DROP_IN_SKETCHES.md) drop-in sketch testing and flags reference

## License

This repository is licensed under the MIT License. See [`LICENSE`](LICENSE).
