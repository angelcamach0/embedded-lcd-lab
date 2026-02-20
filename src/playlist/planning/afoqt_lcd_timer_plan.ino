// AFOQT LCD Timer Plan (pseudo-notes only)
// No implementation code yet. This file defines the design targets first.

// 1) Problem: receiving input from the master script file.
//    - We need a reliable serial protocol from host -> Arduino.
//    - Input should include at least: initial countdown duration in HH:MM:SS.
//    - Optional future fields: section name, control commands (pause/resume/stop).

// 2) Given input must dictate the timer.
//    - Arduino should parse the incoming HH:MM:SS payload.
//    - Parsed value becomes total remaining seconds.
//    - LCD displays live countdown in HH:MM:SS and updates every second.

// 3) Realization: master script already has timer logic.
//    - Host script can act as scheduler/orchestrator for study sections.
//    - Arduino should stay lightweight and focus on display + countdown state.
//    - Avoid duplicating complex scheduling logic in both places.

// 4) Maybe derive timer automatically from sketch/file naming.
//    - Existing naming convention already carries runtime information.
//    - Option A: master script extracts duration from filename and sends it to Arduino.
//    - Option B: Arduino receives only seconds; script remains single source of truth.
//    - Preferred now: Option B (simpler and less parsing on device side).

// 5) Simple timer behavior suggestions.
//    - Validate input: reject malformed HH:MM:SS (or clamp safely).
//    - Use non-blocking update style (millis-based), not long delay chains.
//    - Keep time in total seconds internally; format to HH:MM:SS only for display.
//    - Define end-state behavior: show 00:00:00 and optional "DONE" message.
//    - Optional control commands: PAUSE, RESUME, RESET, STOP.

// 6) How do we exit the program?
//    - Host side: script can stop sending updates / send explicit STOP command.
//    - Device side: on STOP, clear display or show idle prompt and wait for new input.
//    - Safety fallback: if serial goes silent for a timeout, return to idle mode.

