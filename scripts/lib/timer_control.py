#!/usr/bin/env python3
import sys
import time

try:
    import serial
except Exception:
    print("Missing python module: pyserial")
    sys.exit(1)


def usage() -> None:
    # PRE: none
    # POST: usage text is written to stderr.
    print(
        "Usage: timer_control.py <port> START_SECONDS <seconds>"
        " | <port> START_HHMMSS <HHMMSS>"
        " | <port> <PAUSE|RESUME|RESET|STOP|PING>",
        file=sys.stderr,
    )


if len(sys.argv) < 3:
    usage()
    sys.exit(2)

port = sys.argv[1]
action = sys.argv[2].upper()
payload = None

if action == "START_SECONDS":
    if len(sys.argv) != 4:
        usage()
        sys.exit(2)
    raw = sys.argv[3].strip()
    if not raw.isdigit():
        print("Invalid seconds: must be integer >= 0", file=sys.stderr)
        sys.exit(2)
    payload = f"CMD:TIMER|START|SECONDS|{int(raw)}\n"
elif action == "START_HHMMSS":
    if len(sys.argv) != 4:
        usage()
        sys.exit(2)
    raw = sys.argv[3].strip()
    if len(raw) != 6 or not raw.isdigit():
        print("Invalid HHMMSS: must be 6 digits", file=sys.stderr)
        sys.exit(2)
    mm = int(raw[2:4])
    ss = int(raw[4:6])
    if mm > 59 or ss > 59:
        print("Invalid HHMMSS: MM/SS must be <= 59", file=sys.stderr)
        sys.exit(2)
    payload = f"CMD:TIMER|START|HHMMSS|{raw}\n"
elif action in {"PAUSE", "RESUME", "RESET", "STOP", "PING"}:
    if len(sys.argv) != 3:
        usage()
        sys.exit(2)
    payload = f"CMD:TIMER|{action}\n"
else:
    usage()
    sys.exit(2)

try:
    # PRE:
    # - `port` points to a serial device reachable by this user.
    # - `payload` is a validated command string ending with '\n'.
    # POST:
    # - command is transmitted once to the Arduino serial endpoint.
    # - on serial errors, script exits without raising an uncaught exception.
    with serial.Serial(port, 9600, timeout=1) as ser:
        # Uno typically resets on serial open; wait for sketch boot.
        time.sleep(2.0)
        ser.write(payload.encode("ascii", "ignore"))
        ser.flush()
except serial.SerialException as exc:
    print(f"[timer-control] serial error: {exc}", file=sys.stderr)
    sys.exit(0)
