# Code Flow Diagrams

This folder is a map of how each important code file behaves at runtime.
It is useful to reviewers and contributors because they can understand control flow quickly before reading full source files.

## Naming convention

1. Each flow document ends with `_code_flow.md`.
2. Each document references a matching diagram at `docs/diagrams/codeflows/<same_name>_code_flow.svg`.
3. The diagram is a visual summary; the source code remains the source of truth.

## Script flow files

1. [`scripts_run_playlist_code_flow.md`](scripts_run_playlist_code_flow.md)  
Main orchestration flow: env loading, sketch discovery/order, upload loop, timing/token transitions, and serial feed mode.

2. [`scripts_compile_playlist_sketches_code_flow.md`](scripts_compile_playlist_sketches_code_flow.md)  
Build-only flow that stages each `.ino` and compiles it with `arduino-cli` for validation.

3. [`scripts_lib_weather_meta_code_flow.md`](scripts_lib_weather_meta_code_flow.md)  
Location/temperature resolution flow with fallback order (`lat/lon` -> explicit IP -> auto IP -> name lookup).

4. [`scripts_lib_serial_feed_code_flow.md`](scripts_lib_serial_feed_code_flow.md)  
Serial writer flow for line updates sent to the LCD weather/date/time sketch.

5. [`scripts_lib_token_watcher_code_flow.md`](scripts_lib_token_watcher_code_flow.md)  
Completion-token watcher flow used by playlist timing when waiting for `PLAYLIST_DONE`.

6. [`scripts_lib_sanitize_field_code_flow.md`](scripts_lib_sanitize_field_code_flow.md)  
Input sanitization flow for weather/city/tag fields before serial transmission.

## Firmware and shared library flow files

1. [`src_lcd_baseline_code_flow.md`](src_lcd_baseline_code_flow.md)  
Baseline LCD behavior flow used as a simple known-good display test.

2. [`src_lcd_matrix_rain_code_flow.md`](src_lcd_matrix_rain_code_flow.md)  
Matrix-style random character animation flow and completion signaling behavior.

3. [`src_lcd_wakeup_reveal_code_flow.md`](src_lcd_wakeup_reveal_code_flow.md)  
Progressive reveal animation flow for message text, including timing/loop behavior.

4. [`src_lcd_serial_feed_code_flow.md`](src_lcd_serial_feed_code_flow.md)  
Firmware-side parser/render loop for host-provided weather/time/date payloads.

5. [`src_common_lcd_shared_h_code_flow.md`](src_common_lcd_shared_h_code_flow.md)  
Shared helper flow used across sketches for LCD utility logic and consistency.
