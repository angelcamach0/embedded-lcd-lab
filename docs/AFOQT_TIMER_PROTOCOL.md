# AFOQT Timer Serial Protocol (v1)

This document defines the host-to-Arduino command contract for the LCD AFOQT countdown timer.

## Transport

1. Baud rate: `9600`
2. Newline-delimited commands (`\n`)
3. ASCII-safe payloads only
4. Ignore `\r`

## Command format

Each command is a single line:

`CMD:TIMER|<VERB>|<ARG1>|<ARG2>|...`

Examples:

1. `CMD:TIMER|START|HHMMSS|003000`
2. `CMD:TIMER|START|SECONDS|1800`
3. `CMD:TIMER|PAUSE`
4. `CMD:TIMER|RESUME`
5. `CMD:TIMER|RESET`
6. `CMD:TIMER|STOP`
7. `CMD:TIMER|PING`

## Required verbs (v1)

1. `START`
   - `CMD:TIMER|START|HHMMSS|<6-digit>`
   - `CMD:TIMER|START|SECONDS|<int>`
2. `PAUSE`
3. `RESUME`
4. `RESET`
5. `STOP`
6. `PING` (optional heartbeat/diagnostic)

## Expected device behavior

1. On `START`, parse duration and enter running state.
2. On `PAUSE`, freeze countdown value.
3. On `RESUME`, continue countdown from paused value.
4. On `RESET`, restore last started duration (if available).
5. On `STOP`, exit timer state and return to idle display.
6. On invalid command or malformed payload, reject and keep current safe state.

## Host-side timing precedence

Host computes final timer duration before sending `START`:

1. Explicit per-sketch override (if provided by user)
2. Filename `_HHMMSS` duration
3. Script fallback default

The Arduino receives only the resolved runtime value and does not need filename parsing.

## Input validation rules

1. `HHMMSS` must be exactly 6 digits with `MM <= 59`, `SS <= 59`.
2. `SECONDS` must be integer `>= 0`.
3. Out-of-range or malformed payloads are rejected.
4. Unknown verbs are ignored (or logged over serial) without crashing.

## Minimal ACK/NACK recommendation

Device may print one-line status responses:

1. `ACK:TIMER|START`
2. `ACK:TIMER|PAUSE`
3. `ACK:TIMER|STOP`
4. `NACK:TIMER|BAD_FORMAT`
5. `NACK:TIMER|BAD_RANGE`

## Example session

1. Host uploads timer sketch.
2. Host opens serial and sends:
   - `CMD:TIMER|START|HHMMSS|003000`
3. Device begins countdown from `00:30:00`.
4. Host sends `CMD:TIMER|PAUSE`.
5. Host sends `CMD:TIMER|RESUME`.
6. Host sends `CMD:TIMER|STOP` to end early.

