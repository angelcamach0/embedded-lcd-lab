# Privacy Notes

This document explains what data this project sends externally when using [`scripts/run_playlist.sh`](scripts/run_playlist.sh).

## Default behavior

The Arduino sketches themselves do not perform network access. Network access happens only in the host script when serial weather mode is enabled.

## Data sent by weather mode

When `ENABLE_SERIAL_FEED=true`, the host may call:

1. `https://geocoding-api.open-meteo.com`
2. `https://api.open-meteo.com`
3. `https://wttr.in` (fallback)

The script sends either:

1. A location string (`WEATHER_LOCATION`), or
2. Coordinates (`WEATHER_LAT`, `WEATHER_LON`)

No authentication tokens are required for these calls.

## Data not collected by this repo

This repo does not implement:

1. User login
2. Analytics SDKs
3. Cloud database writes
4. Telemetry upload from Arduino firmware

## How to disable outbound weather requests

Edit [`scripts/run_playlist.sh`](scripts/run_playlist.sh):

1. Set `ENABLE_SERIAL_FEED=false`, or
2. Keep serial feed enabled but replace weather fetch logic with a fixed local value

## Local serial behavior

The script writes LCD text payloads to the local serial port (for example `/dev/ttyACM0`) in the format:

`line1|line2`

No personal files are uploaded by design.
