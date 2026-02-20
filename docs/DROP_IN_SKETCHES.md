# Drop-In Sketch Workflow

This guide explains how to add new sketches and have the playlist script discover/run them.

## How discovery works

When `AUTO_DISCOVER_SKETCHES=true`, [`scripts/run_playlist.sh`](../scripts/run_playlist.sh) scans [`src/playlist/`](../src/playlist/) for `.ino` files.

Discovery order rule:

1. Numeric prefix before first underscore (for example `01_name`, `10_name`) ascending.
2. If numeric prefixes are equal, alphabetical by remaining name.
3. If no numeric prefix is present, item is treated as lower priority (sorted after numbered entries).

Optional duration suffix:

1. Full recommended pattern: `NN_name_HHMMSS.ino`.
2. `NN_` controls playback sequence:
   - lower `NN` runs first;
   - if `NN` matches, alphabetical order by `name` is used.
3. Preferred: use `_HHMMSS` at end of filename (before `.ino`) to define per-sketch duration.
4. `HHMMSS` is interpreted as hours/minutes/seconds:
   - `000010` => 10 seconds
   - `000100` => 1 minute
   - `013000` => 1 hour 30 minutes
5. Legacy `_TTT` is disabled by default.
6. Enable legacy `_TTT` only when needed with:
   - flag: `--enable-legacy-ttt-duration true`
   - or env: `ENABLE_LEGACY_TTT_DURATION=true`
7. If suffix is missing or invalid, script falls back to existing default behavior.

Built-in serial weather behavior:

1. Dedicated serial weather sketch is auto-detected by pattern:
   `04_lcd_city_datetime_temp_feed_*.ino`
2. It remains in normal discovery order.
3. When that sketch is active, the host script pushes weather/time lines for `SERIAL_FEED_SECONDS`.

## Add a new sketch

1. Add a new `.ino` file under [`src/playlist/`](../src/playlist/):
   - example: `src/playlist/05_lcd_dropin_test.ino`
2. Run playlist with discovery enabled.

## Recommended test command (first pass)

Use timeout mode first so your sketch does not need to emit a done token:

```bash
cd scripts
./run_playlist.sh --auto-discover true --wait-for-done false --cycles 1
```

## Token mode (optional)

If your sketch prints:

`PLAYLIST_DONE`

then you can run token-driven switching:

```bash
./run_playlist.sh --auto-discover true --wait-for-done true --cycles 1
```

## Useful flags

1. `AUTO_DISCOVER_SKETCHES=true|false`
2. `WAIT_FOR_DONE=true|false`
3. `PLAYLIST_CYCLES=0|N` (`0` means infinite)
4. `PORT=/dev/ttyACM0` (or your device port)
5. `ENABLE_SERIAL_FEED=true|false`
6. `SERIAL_FEED_SECONDS=N`
7. `WEATHER_LOCATION=...` or `WEATHER_LAT=... WEATHER_LON=...`
8. `WEATHER_IP=8.8.8.8` (optional IPv4/IPv6 geolocation override)
9. `LOCAL_LIBRARIES_DIR=src/common` (default shared library path)
10. `PRECOMPILE_ONCE=true|false` (reuse compiled artifacts across cycles)
11. `UPLOAD_SETTLE_SECONDS=0.9` (small delay after upload for serial stability)
12. `ENABLE_LEGACY_TTT_DURATION=true|false` (default false)
13. `DURATION_OVERRIDE_HHMMSS=HHMMSS` (optional global runtime override)

Equivalent CLI flags are also supported:

1. `--auto-discover true|false`
2. `--wait-for-done true|false`
3. `--cycles N`
4. `--port /dev/ttyACM0`
5. `--enable-serial-feed true|false`
6. `--serial-feed-seconds N`
7. `--weather-location "City"` or `--weather-lat ... --weather-lon ...`
8. `--weather-ip 8.8.8.8` (optional IPv4/IPv6 geolocation override)
9. `--precompile-once true|false`
10. `--upload-settle-seconds 0.9`
11. `--enable-legacy-ttt-duration true|false`
12. `--duration-override-hhmmss HHMMSS`

## Common pitfalls

1. If `WAIT_FOR_DONE=true` and sketch never prints token, transition happens only on timeout.
2. Repeated rapid skips can cause temporary serial port contention.
3. Keep Arduino IDE Serial Monitor closed during playlist runs.
4. Space key skip always overrides current wait/hold path and advances to next stage.
5. If `WAIT_FOR_DONE=true` and a duration suffix exists, that duration becomes token timeout for that sketch.

## See also

1. [`SERIAL_PROTOCOL.md`](SERIAL_PROTOCOL.md)
2. [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)
3. [`../README.md`](../README.md)
