#!/usr/bin/env python3
import re
import sys
import time
from datetime import datetime

try:
    import serial
except Exception:
    print("Missing python module: pyserial")
    sys.exit(1)

if len(sys.argv) != 6:
    print("Usage: serial_feed.py <port> <duration_s> <weather> <city> <tag>", file=sys.stderr)
    sys.exit(2)

port = sys.argv[1]
duration = int(sys.argv[2])
weather = sys.argv[3]
city = sys.argv[4]
tag = (sys.argv[5] or "--")[:2]

# PRE:
# - weather input is sanitized ASCII-like text from host weather resolver.
# POST:
# - temp_c holds canonical Celsius value when parseable; otherwise None.
# Parse weather once (expected like "17.1C"), then toggle C/F locally.
temp_c = None
m = re.match(r"^\s*([+-]?\d+(?:\.\d+)?)\s*([CFcf]?)\s*$", weather or "")
if m:
    v = float(m.group(1))
    u = (m.group(2) or "C").upper()
    temp_c = (v - 32.0) * (5.0 / 9.0) if u == "F" else v

try:
    # PRE:
    # - port exists and current user can open it.
    # - duration is a non-negative integer.
    # POST:
    # - emits 1 payload/second until duration expires or serial fails.
    with serial.Serial(port, 9600, timeout=1) as ser:
        # UNO resets when serial opens; wait once for sketch boot.
        time.sleep(2.0)
        end_ts = time.time() + duration
        while time.time() < end_ts:
            # Loop invariant:
            # - line1 is always exactly 16 chars.
            # - line2 is clamped to 16 chars to prevent LCD overflow.
            now = datetime.now()
            show_date = ((int(time.time()) // 5) % 2) == 1

            # Alternate top row: time <-> date every 5 seconds.
            if show_date:
                base = now.strftime("%b %d %Y")
            else:
                base = now.strftime("%H:%M:%S")

            # Top-right 2 chars reserved for region tag.
            line1_chars = list((base + (" " * 16))[:16])
            if len(tag) >= 1:
                line1_chars[14] = tag[0]
            if len(tag) >= 2:
                line1_chars[15] = tag[1]
            line1 = "".join(line1_chars)

            if temp_c is None:
                wx = weather
            else:
                show_f = ((int(time.time()) // 5) % 2) == 1
                if show_f:
                    v = temp_c * (9.0 / 5.0) + 32.0
                    wx = f"{v:.1f}F"
                else:
                    wx = f"{temp_c:.1f}C"

            line2 = f"Wx {wx} {city}"[:16]
            payload = f"{line1}|{line2}\n"
            try:
                ser.write(payload.encode("utf-8", "ignore"))
                ser.flush()
            except serial.SerialException as exc:
                print(f"[serial-feed] stopped: {exc}", file=sys.stderr)
                sys.exit(0)
            time.sleep(1.0)
except serial.SerialException as exc:
    print(f"[serial-feed] unable to open port: {exc}", file=sys.stderr)
    sys.exit(0)
