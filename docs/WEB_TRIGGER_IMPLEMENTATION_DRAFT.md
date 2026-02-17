# Web Trigger Implementation Draft

Status: rough planning notes only (no runtime feature merged yet).

## Goal

Allow a user action from a website/app to trigger LCD updates on the Arduino system with safe defaults and easy replication.

## Scope for phase 1 (minimal viable)

1. Keep current playlist architecture intact.
2. Add host-side bridge that accepts a command and forwards sanitized payload over serial.
3. No public internet dependency required for first demo (local-only mock endpoint).

## Proposed architecture

1. New script: `scripts/lib/web_bridge.py`
2. Bridge modes:
- local file poll: read commands from a local JSON file
- local HTTP poll: read command from local API endpoint
3. Bridge output:
- writes `line1|line2\n` to the same serial contract used by `04_lcd_city_datetime_temp_feed_*.ino`

## Command model (phase 1)

Single command shape:

```json
{
  "type": "show_text",
  "line1": "Hello",
  "line2": "From web"
}
```

Rules:

1. Only allow known `type` values.
2. Clamp each line to LCD width.
3. Filter non-printable characters.
4. Reject unknown keys (strict schema).

## Security baseline

1. Local-only by default (localhost or file).
2. If remote endpoint is enabled later:
- require HMAC signature
- require timestamp and nonce
- reject stale/replayed requests
3. Add rate limits (for example max 1 accepted command per second).
4. Log rejected events with reason (invalid signature/schema/rate limit).

## Integration points

1. `scripts/run_playlist.sh`
- optional mode: `ENABLE_WEB_BRIDGE=true`
- choose when bridge runs:
  - during `04_lcd_city_datetime_temp_feed` segment only, or
  - as a dedicated segment
2. `docs/SERIAL_PROTOCOL.md`
- keep backward-compatible payload
- optionally document future command verbs (`CMD:SHOW|...`)

## Milestones

1. M1: local file mock backend
- poll `runtime/commands.json`
- send validated payload to serial
2. M2: local HTTP backend
- fetch from `http://127.0.0.1:PORT/next-command`
3. M3: auth hardening for remote mode
- HMAC + replay protection
4. M4: docs + examples
- `.env.example` additions
- troubleshooting entries

## Test plan

1. Unit-level checks (host side)
- schema validation
- sanitizer behavior
- replay/timestamp rejection logic
2. Hardware integration checks
- Arduino receives payload and updates display
- malformed commands do not crash bridge
- rapid command bursts are rate-limited

## Open decisions

1. Should web-trigger run continuously or only in selected playlist windows?
2. Keep protocol as plain `line1|line2`, or introduce command verbs now?
3. Should accepted commands be persisted for audit/debug?

## Related docs

1. `FUTURE_IDEAS_AND_IMPLEMENTATION_PLAN.md`
2. `SERIAL_PROTOCOL.md`
3. `TROUBLESHOOTING.md`
4. `codeflows/scripts_run_playlist.md`
