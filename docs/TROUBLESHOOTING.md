# Troubleshooting

This page maps common errors to practical fixes.

## 1) Upload fails with permission denied

### Symptoms

- `OS error: cannot open port /dev/ttyACM0: Permission denied`
- `Error: unable to open port /dev/ttyACM0 for programmer arduino`

### Fix

```bash
sudo usermod -aG dialout "$USER"
newgrp dialout
```

Then unplug/replug the board and retry.

## 2) Port busy or random upload failures

### Symptoms

- `programmer is not responding`
- `not in sync`
- `device reports readiness to read but returned no data`
- `Resource temporarily unavailable`

### Why it happens

Serial monitor/process contention during rapid upload + watch cycles.

### Fix

1. Close Arduino IDE Serial Monitor/Plotter.
2. Stop any other process using the same port.
3. Retry upload.
4. If needed, unplug/replug USB and run again.

Useful checks:

```bash
lsof /dev/ttyACM0
fuser /dev/ttyACM0
```

## 3) `arduino-cli` missing

### Symptoms

- `Missing required command: arduino-cli`

### Fix

Install `arduino-cli` and verify:

```bash
arduino-cli version
```

If you installed it to a non-default path, run with:

```bash
ARDUINO_CLI=/full/path/to/arduino-cli ./scripts/run_playlist.sh
```

## 4) AVR platform not installed

### Symptoms

- `Platform 'arduino:avr' not found: platform not installed`

### Fix

```bash
arduino-cli core update-index
arduino-cli core install arduino:avr
```

## 5) `LiquidCrystal.h: No such file or directory`

### Symptoms

- compile fails for LCD sketches with missing `LiquidCrystal.h`

### Fix

```bash
arduino-cli lib update-index
arduino-cli lib install LiquidCrystal
```

## 6) Weather shows `Wx N/A` or stale value

### Symptoms

- LCD shows `Wx N/A`
- terminal logs timeout/handshake errors for weather endpoints

### Why it happens

Weather providers can timeout or network can be unstable.

### Fix

1. Check internet connectivity.
2. Set explicit coordinates in `.env` to avoid geocoding dependency:
   - `WEATHER_LAT=...`
   - `WEATHER_LON=...`
3. Reduce dependency on network by disabling weather mode:
   - `ENABLE_SERIAL_FEED=false`

## 7) LCD backlight turns off / screen looks dead

### Symptoms

- backlight flashes then fades
- no visible text even though upload succeeded

### Fix

1. Ensure LCD pin `K` (pin 16) goes to GND.
2. Ensure LCD pin `A` (pin 15) goes to 5V (prefer ~220 ohm series resistor).
3. Set contrast correctly:
   - best: 10k potentiometer on `VO`
   - temporary test: tie `VO` to GND

See [`wiring.md`](wiring.md) for full pin map.

## 8) Board not detected in `arduino-cli board list`

### Symptoms

- no boards listed

### Fix

1. Check USB cable (data cable, not charge-only).
2. Reconnect board and check `/dev/ttyACM*` or `/dev/ttyUSB*`.
3. Try another USB port.
4. If using sandboxed tooling (for example snap), ensure required USB interfaces are connected.

## 9) Playlist does not skip on Space key

### Symptoms

- pressing Space does nothing

### Why it happens

Skip input only works with interactive terminal stdin.

### Fix

Run script in a normal terminal session (not detached/non-interactive job).

## 10) Config values not applying

### Symptoms

- script behaves as defaults despite edits

### Fix

1. Verify `.env` exists at repo root.
2. Confirm keys are valid `KEY=VALUE` format.
3. Avoid shell syntax in `.env` (no command substitution).
4. If using custom env file, launch with:

```bash
ENV_FILE=/path/to/custom.env ./scripts/run_playlist.sh
```

## 11) Playlist timing feels wrong in token mode

### Symptoms

- sketch changes sooner/later than expected with `WAIT_FOR_DONE=true`

### Why it happens

In token mode, file suffix `_TTT` is treated as timeout for done-token wait.

### Fix

1. Tune `_TTT` in sketch filename (`mss` format), or
2. Run with `--wait-for-done false` to use hold-timer mode directly.

## 12) `--weather-ip` does not work

### Symptoms

- logs show `invalid weather-ip format`
- location falls back to auto-IP or `WEATHER_LOCATION`

### Fix

1. Use valid IP format only:
   - IPv4 example: `8.8.8.8`
   - IPv6 example: `2606:4700:4700::1111`
2. Do not include URL/protocol/path (invalid examples):
   - `https://8.8.8.8`
   - `8.8.8.8:443`
   - `8.8.8.8/something`

## See also

1. [`REPLICATION_REQUIREMENTS.md`](REPLICATION_REQUIREMENTS.md)
2. [`wiring.md`](wiring.md)
3. [`LESSONS_LEARNED.md`](LESSONS_LEARNED.md)
4. [`../README.md`](../README.md)
