#!/usr/bin/env python3
import sys
import time

try:
    import serial
except Exception:
    print("Missing python module: pyserial")
    sys.exit(2)

if len(sys.argv) != 4:
    print("Usage: token_watcher.py <port> <token> <timeout_seconds>", file=sys.stderr)
    sys.exit(2)

port = sys.argv[1]
token = sys.argv[2]
timeout = int(sys.argv[3])

try:
    with serial.Serial(port, 9600, timeout=0.5) as ser:
        # Opening serial can reset Uno; give sketch time to boot.
        time.sleep(2.0)
        end = time.time() + timeout
        while time.time() < end:
            try:
                line = ser.readline().decode("utf-8", "ignore").strip()
            except serial.SerialException as exc:
                print(f"[serial] watcher stopped: {exc}", file=sys.stderr)
                sys.exit(4)
            if line:
                print(f"[serial] {line}")
            if token in line:
                sys.exit(0)
        sys.exit(1)
except serial.SerialException as exc:
    print(f"[serial] unable to open port: {exc}", file=sys.stderr)
    sys.exit(4)
