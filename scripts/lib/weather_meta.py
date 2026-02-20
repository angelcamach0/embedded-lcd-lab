#!/usr/bin/env python3
import ipaddress
import json
import sys
import urllib.parse
import urllib.request

if len(sys.argv) != 5:
    print(
        "Usage: weather_meta.py <location> <lat_or_empty> <lon_or_empty> <ip_or_empty>",
        file=sys.stderr,
    )
    sys.exit(2)

location = sys.argv[1]
lat_arg = sys.argv[2].strip()
lon_arg = sys.argv[3].strip()
ip_arg = sys.argv[4].strip()

STATE_ABBR = {
    "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR", "California": "CA",
    "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE", "Florida": "FL", "Georgia": "GA",
    "Hawaii": "HI", "Idaho": "ID", "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS",
    "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME", "Maryland": "MD", "Massachusetts": "MA",
    "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS", "Missouri": "MO", "Montana": "MT",
    "Nebraska": "NE", "Nevada": "NV", "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM",
    "New York": "NY", "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK",
    "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC", "South Dakota": "SD",
    "Tennessee": "TN", "Texas": "TX", "Utah": "UT", "Vermont": "VT", "Virginia": "VA", "Washington": "WA",
    "West Virginia": "WV", "Wisconsin": "WI", "Wyoming": "WY", "District of Columbia": "DC",
}


def fetch_text(url: str, timeout: int = 8) -> str:
    # PRE: url is a complete HTTP(S) endpoint string.
    # POST: returns stripped response text or propagates transport errors.
    req = urllib.request.Request(url, headers={"User-Agent": "embedded-lcd-lab"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", "ignore").strip()


def fetch_json(url: str, timeout: int = 8):
    # PRE: endpoint returns JSON payload.
    # POST: parsed JSON object/dict is returned.
    return json.loads(fetch_text(url, timeout=timeout))


def clean_ascii(s: str) -> str:
    # PRE: input may include unicode/whitespace from upstream APIs.
    # POST: returns printable ASCII-only string for stable LCD rendering.
    s = (s or "").strip()
    return "".join(ch for ch in s if 32 <= ord(ch) <= 126)


def state_tag(admin1: str, country_code: str) -> str:
    # PRE: admin1/country_code may be empty or noisy.
    # POST: returns 2-char region tag fallback-safe for LCD header.
    admin1 = clean_ascii(admin1)
    cc = clean_ascii(country_code).upper()
    if cc == "US":
        if len(admin1) == 2 and admin1.isalpha():
            return admin1.upper()
        return STATE_ABBR.get(admin1, "US")
    if len(cc) == 2:
        return cc
    return "--"


city = clean_ascii(location) or "City"
tag = "--"
lat = None
lon = None
source = "unknown"


def try_ip_geolocation(target_ip: str):
    # Uses ipapi.co:
    # - auto mode: /json/
    # - explicit IP mode: /<ip>/json/
    # Returns tuple: (lat, lon, city, tag) or None on failure.
    try:
        # PRE:
        # - target_ip is either empty (auto mode) or a candidate IP string.
        # POST:
        # - returns tuple(lat, lon, city, tag) on success.
        # - returns None on validation/provider failures.
        url = "https://ipapi.co/json/"
        if target_ip:
            # Strict IP format validation (IPv4 or IPv6).
            ip_obj = ipaddress.ip_address(target_ip)
            url = f"https://ipapi.co/{urllib.parse.quote(str(ip_obj))}/json/"
        data = fetch_json(url, timeout=8)
        if data.get("error"):
            return None
        lat_v = data.get("latitude")
        lon_v = data.get("longitude")
        if lat_v is None or lon_v is None:
            return None

        city_v = clean_ascii(data.get("city") or city)
        region_v = clean_ascii(data.get("region") or data.get("region_name") or "")
        cc_v = clean_ascii(data.get("country_code") or "")
        tag_v = state_tag(region_v, cc_v)
        return (float(lat_v), float(lon_v), city_v or city, tag_v)
    except ValueError as exc:
        # Raised by ipaddress when explicit --weather-ip format is invalid.
        print(f"[weather] invalid weather-ip format: {exc}", file=sys.stderr)
    except Exception as exc:
        print(f"[weather] ip geolocation failed: {exc}", file=sys.stderr)
    return None

# 1) Resolve location metadata.
# PRE:
# - location inputs are CLI-derived strings.
# POST:
# - best-effort coordinates/city/tag/source are resolved via priority chain.
try:
    # Priority 1: explicit coordinates (strongest override).
    if lat_arg and lon_arg:
        lat = float(lat_arg)
        lon = float(lon_arg)
        source = "latlon"
        rev = fetch_json(
            f"https://geocoding-api.open-meteo.com/v1/reverse?latitude={lat}&longitude={lon}&count=1"
        )
        results = rev.get("results") or []
        if results:
            city = clean_ascii(results[0].get("name") or city)
            tag = state_tag(results[0].get("admin1", ""), results[0].get("country_code", ""))
    else:
        # Priority 2: explicit weather IP override, if provided.
        ip_res = try_ip_geolocation(ip_arg) if ip_arg else None
        if ip_res:
            lat, lon, city, tag = ip_res
            source = "weather_ip"
        else:
            # Priority 3: auto-detect by current public IP.
            auto_ip_res = try_ip_geolocation("")
            if auto_ip_res:
                lat, lon, city, tag = auto_ip_res
                source = "auto_ip"
            else:
                # Priority 4: fallback to configured location text.
                q = urllib.parse.quote(location)
                geo = fetch_json(f"https://geocoding-api.open-meteo.com/v1/search?name={q}&count=1")
                results = geo.get("results") or []
                if not results:
                    raise RuntimeError("location not found")
                lat = float(results[0]["latitude"])
                lon = float(results[0]["longitude"])
                city = clean_ascii(results[0].get("name") or city)
                tag = state_tag(results[0].get("admin1", ""), results[0].get("country_code", ""))
                source = "location_fallback"
except Exception as exc:
    print(f"[weather] geocode failed: {exc}", file=sys.stderr)

# 2) Open-Meteo current temperature.
# PRE: lat/lon are set from resolver step.
# POST: prints weather|city|tag|source and exits on success.
try:
    if lat is None or lon is None:
        raise RuntimeError("missing coordinates")
    wx = fetch_json(
        f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m"
    )
    temp = wx.get("current", {}).get("temperature_2m")
    if temp is None:
        raise RuntimeError("missing temperature")
    weather = f"{float(temp):.1f}C"
    print(f"{weather}|{city}|{tag}|{source}")
    raise SystemExit(0)
except Exception as exc:
    print(f"[weather] open-meteo failed: {exc}", file=sys.stderr)

# 3) Fallback to wttr.in.
# PRE: Open-Meteo path failed.
# POST: best-effort fallback output; final line always printed.
try:
    q = urllib.parse.quote(city)
    wttr = fetch_text(f"https://wttr.in/{q}?format=%t", timeout=8)
    wttr = wttr.replace(" ", "")
    if wttr:
        if source == "unknown":
            source = "wttr_fallback"
        print(f"{wttr}|{city}|{tag}|{source}")
        raise SystemExit(0)
except Exception as exc:
    print(f"[weather] wttr.in failed: {exc}", file=sys.stderr)

if source == "unknown":
    source = "none"
print(f"N/A|{city}|{tag}|{source}")
