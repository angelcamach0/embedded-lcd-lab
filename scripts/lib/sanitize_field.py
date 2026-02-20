#!/usr/bin/env python3
import re
import sys

if len(sys.argv) != 3:
    print("Usage: sanitize_field.py <weather|city|tag> <value>", file=sys.stderr)
    sys.exit(2)

kind = sys.argv[1]
value = (sys.argv[2] or "").strip()

if kind == "weather":
    # PRE: weather value may contain units/symbols from upstream providers.
    # POST: compact LCD-safe token (max 8 chars) or "N/A".
    # Keep only compact ASCII chars useful on 16x2 LCD.
    value = value.replace("°", "")
    value = re.sub(r"[^0-9A-Za-z+./-]", "", value)
    print(value[:8] if value else "N/A")
elif kind == "city":
    # PRE: city string may contain punctuation/UTF-8.
    # POST: sanitized city fragment (max 10 chars) or "City".
    value = re.sub(r"[^0-9A-Za-z .-]", "", value)
    print(value[:10] if value else "City")
elif kind == "tag":
    # PRE: region tag may be lower/mixed/non-alnum.
    # POST: uppercase 2-char tag or default "--".
    value = re.sub(r"[^A-Z0-9]", "", value.upper())
    print(value[:2] if value else "--")
else:
    print(f"Unsupported kind: {kind}", file=sys.stderr)
    sys.exit(2)
