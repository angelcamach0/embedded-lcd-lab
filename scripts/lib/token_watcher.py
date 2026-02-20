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
    # PRE:
    # - port can be opened by this process.
    # - token is non-empty and timeout is >= 0.
    # POST:
    # - exits 0 when token observed.
    # - exits 1 on timeout.
    # - exits 4 on serial access/read failures.
    with serial.Serial(port, 9600, timeout=0.5) as ser:
        # Opening serial can reset Uno; give sketch time to boot.
        time.sleep(2.0)
        end = time.time() + timeout
        while time.time() < end:
            # Read-line loop:
            # - prints non-empty serial lines for operator visibility.
            # - performs substring token match to avoid strict framing coupling.
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
