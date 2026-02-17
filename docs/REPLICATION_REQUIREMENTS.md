# Replication Requirements

This file lists what a user needs installed to reproduce this project.

## Hardware

1. Arduino Uno (or compatible board supported by `arduino:avr:uno`)
2. HD44780-compatible character LCD (tested with 16x2)
3. Breadboard + jumper wires
4. Recommended:
   - 10k potentiometer for contrast (`VO`)
   - ~220 ohm resistor for LCD backlight (`A`)

## OS and tools

1. Linux/macOS/Windows with USB serial support
2. `arduino-cli`
3. Python 3
4. `pip` for installing Python packages

## Arduino core/library requirements

Install Arduino AVR core and LiquidCrystal library:

```bash
arduino-cli core update-index
arduino-cli core install arduino:avr
arduino-cli lib update-index
arduino-cli lib install LiquidCrystal
```

Project-local shared library used by sketches:

1. [`src/common/lcd_shared`](src/common/lcd_shared)

## Python package requirements

```bash
python3 -m pip install --user pyserial
```

## Optional network requirements

Needed only if weather serial feed is enabled:

1. outbound HTTPS access to:
   - `ipapi.co` (public-IP geolocation)
   - `api.open-meteo.com`
   - `geocoding-api.open-meteo.com`
   - `wttr.in` (fallback)

If you want fully local/offline operation, disable weather feed in [`scripts/run_playlist.sh`](scripts/run_playlist.sh):

1. `ENABLE_SERIAL_FEED=false`

## Linux serial permissions

If upload fails with `Permission denied` on `/dev/ttyACM*`:

```bash
sudo usermod -aG dialout "$USER"
newgrp dialout
```

## Quick verification checklist

0. `cp .env.example .env` and adjust values for your board/port/location
1. `arduino-cli board list` shows your board/port
2. [`./scripts/compile_playlist_sketches.sh`](./scripts/compile_playlist_sketches.sh) succeeds
3. `bash -n scripts/run_playlist.sh` succeeds
4. LCD baseline sketch prints expected text
5. [`./scripts/run_playlist.sh`](./scripts/run_playlist.sh) starts auto-discovered playlist loop (default `PLAYLIST_CYCLES=0`)

## See also

1. [`wiring.md`](wiring.md) for pin-by-pin wiring
2. [`LESSONS_LEARNED.md`](LESSONS_LEARNED.md) for common setup failures
3. [`SERIAL_PROTOCOL.md`](SERIAL_PROTOCOL.md) for payload format and done-token behavior
4. [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) for fast error-to-fix mapping
5. [`../README.md`](../README.md) for playlist usage and runtime configuration
6. [`INDEX.md`](INDEX.md) for full documentation navigation
