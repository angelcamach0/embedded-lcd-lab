# Embedded LCD Lab

Arduino Uno + HD44780 16x2 LCD project for animation experiments, serial text rendering, and a host-driven sketch playlist workflow.

## What this repo does

1. Provides standalone LCD sketches (`baseline`, `matrix`, `wakeup reveal`, `serial feed`).
2. Provides a host script (`scripts/run_playlist.sh`) that uploads sketches in sequence.
3. Pushes live time/date/weather text to the serial-feed sketch.
4. Documents wiring, animation logic, and future offline architecture plans.

## Hardware

1. Arduino Uno (or compatible board with `arduino:avr:uno` profile)
2. HD44780-compatible 16x2 LCD (16-pin)
3. Breadboard + jumper wires
4. Recommended: 10k potentiometer for LCD contrast (`VO`)
5. Recommended: ~220 ohm resistor for LCD backlight anode (`A`)

See `docs/wiring.md` for the current tested map.

## Software requirements

1. `arduino-cli`
2. Python 3
3. Python module `pyserial`
4. Optional internet access (only needed for live weather fetch)

## Quick start

```bash
git clone <your-repo-url>
cd embedded-lcd-lab
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

Example with explicit port + fixed coordinates:

```bash
PORT=/dev/ttyACM0 WEATHER_LAT=31.7619 WEATHER_LON=-106.4850 ./run_playlist.sh
```

## Compile sketches manually

```bash
arduino-cli compile --fqbn arduino:avr:uno src/lcd_baseline
arduino-cli compile --fqbn arduino:avr:uno src/lcd_wakeup_reveal
arduino-cli compile --fqbn arduino:avr:uno src/lcd_matrix_rain
arduino-cli compile --fqbn arduino:avr:uno src/lcd_serial_feed
```

## Keyboard controls

1. Press `Space` to skip to the next sketch.
2. Press `Space` during weather feed to skip weather mode early.

## Weather/time behavior

1. Weather is fetched once per weather segment.
2. Celsius/Fahrenheit toggles every 5 seconds from one fetched value.
3. Top row alternates every 5 seconds:
   - `HH:MM:SS`
   - `Mon DD YYYY`
4. Top-right 2 characters show region tag (US state abbreviation when available, otherwise country code/default).

## Configuration

Main runtime config is at the top of `scripts/run_playlist.sh`:

1. `PORT`, `BOARD_FQBN`, `ARDUINO_CLI`
2. `SKETCHES`, `HOLD_SECONDS`, `AUTO_DISCOVER_SKETCHES`
3. `WAIT_FOR_DONE`, `DONE_TOKEN`, `DONE_TIMEOUT_SECONDS`
4. `ENABLE_SERIAL_FEED`, `SERIAL_FEED_SECONDS`
5. `WEATHER_LOCATION`, `WEATHER_LAT`, `WEATHER_LON`
6. `PLAYLIST_CYCLES`
7. `POST_SKIP_COOLDOWN_SECONDS`, `PORT_WAIT_TIMEOUT_SECONDS`

## Privacy and security notes

1. This repo does not contain API keys or authentication secrets.
2. The weather feature sends either:
   - configured coordinates (`WEATHER_LAT/WEATHER_LON`), or
   - configured location text (`WEATHER_LOCATION`)
   to public weather/geocoding endpoints.
3. If you do not want any outbound network calls, disable serial weather feed in `run_playlist.sh`:
   - set `ENABLE_SERIAL_FEED=false`

See `PRIVACY.md` for full details.

## Safety and liability

This project is for educational use. You are responsible for wiring, power limits, and safe operation of your hardware. See `DISCLAIMER.md`.

## Repo layout

1. `src/` sketches
2. `scripts/` host automation
3. `docs/` design notes, wiring, and plans
4. `docs/GITHUB_PUBLISH_CHECKLIST.md` release/publish steps

## License

This repository is licensed under the MIT License. See `LICENSE`.
