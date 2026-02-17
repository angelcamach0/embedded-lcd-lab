# src/playlist/04_lcd_city_datetime_temp_feed_100.ino

Code file: [`src/playlist/04_lcd_city_datetime_temp_feed_100.ino`](src/playlist/04_lcd_city_datetime_temp_feed_100.ino)

## Flow diagram

![src/playlist/04_lcd_city_datetime_temp_feed_100.ino diagram](../diagrams/codeflows/src_lcd_serial_feed_code_flow.svg)

## Mermaid source

```mermaid
flowchart TD
  A[setup] --> B[Init LCD and waiting text]
  B --> C[Init serial and buffers]
  C --> D[loop read serial bytes]
  D --> E{Byte is newline}
  E -->|yes| F[Terminate buffer and parse payload]
  F --> G[Split first delimiter into row1 row2]
  G --> H[Clamp rows and render full width]
  E -->|no| I{Printable non carriage return}
  I -->|yes| J{Buffer below INPUT_MAX}
  J -->|yes| K[Append byte]
  J -->|no| L[Reset buffer overflow]
  I -->|no| M[Ignore byte]
  H --> D
  K --> D
  L --> D
  M --> D
```
