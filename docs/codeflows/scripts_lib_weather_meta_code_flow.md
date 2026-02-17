# scripts/lib/weather_meta.py

Code file: [`scripts/lib/weather_meta.py`](scripts/lib/weather_meta.py)

## Flow diagram

![scripts/lib/weather_meta.py diagram](../diagrams/codeflows/scripts_lib_weather_meta_code_flow.svg)

## Mermaid source

```mermaid
flowchart TD
  A[Input: location lat lon ip] --> B{Coordinates provided?}
  B -->|yes| C[Reverse geocode from lat lon]
  C --> E[Resolve city and region tag]
  B -->|no| D{Explicit weather IP provided?}
  D -->|yes| F[IP geolocation with validation]
  F --> G{IP lookup success?}
  G -->|yes| E
  G -->|no| H[Try auto public IP geolocation]
  D -->|no| H
  H --> I{Auto IP success?}
  I -->|yes| E
  I -->|no| J[Fallback geocode by location name]
  J --> E
  E --> K[Request Open-Meteo current temperature]
  K --> L{Temperature available?}
  L -->|yes| M[Print weather city tag and source]
  L -->|no| N[Fallback to wttr.in]
  N --> O{Fallback success?}
  O -->|yes| M
  O -->|no| P[Print N or A city tag and source]
```
