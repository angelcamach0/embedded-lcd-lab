# Engineering Quality and Roadmap

This document captures current quality posture, critique, and next additions.

## What Was Improved

1. Pre/post-condition comments were added to timer control and interactive helpers.
2. Timer firmware command paths now document parser safety and state transition expectations.
3. Playlist duration resolution was refactored into reusable functions to reduce duplicate logic.
4. Interactive playlist selection now applies once per run and does not reprompt every cycle.
5. `--print-playlist-plan` was added for pre-run verification of resolved timing behavior.
6. Duration parsing and override predicates were extracted into `scripts/lib/duration_policy.sh`.
7. Serial port lifecycle/retry helpers were extracted into `scripts/lib/port_control.sh`.
8. Interactive playlist selection/override helpers were extracted into `scripts/lib/interactive_playlist.sh`.
9. Build/cache/upload helpers were extracted into `scripts/lib/build_upload.sh`.

## SOLID-Oriented Notes (Applied Pragmatically)

1. Single Responsibility
   - `playlist_interactive.py`: only user selection + override capture.
   - `timer_control.py`: only command construction/transmission.
   - `run_playlist.sh`: orchestration and sequencing.
2. Open/Closed
   - Duration resolution is centralized, so new sources can be added without rewriting loop bodies.
3. Interface Segregation (practical shell form)
   - Small helper functions (`resolve_effective_duration`, `should_apply_global_override_for_sketch`) isolate policy checks.
4. Dependency direction
   - Host script depends on helper scripts via narrow CLI contracts, not shared mutable internals.

## Critique and Risks

1. Shell script complexity remains high.
   - Mitigation: keep extracting policy logic into helpers and Python modules.
2. Mixed policy/runtime concerns still live in `run_playlist.sh`.
   - Mitigation: split into orchestration core + profile/policy module.
3. Interactive mode currently terminal-dependent.
   - Mitigation: keep a non-interactive path and machine-readable outputs.

## Next Additions (Recommended Order)

1. Add `--interactive-once` profile in `.env` to make study workflow default.
2. Add `--skip-timer-prompts` for batch runs.
3. Add optional persistent session profiles (`profiles/*.json`) for saved sketch sets.
4. Add minimal automated tests for duration policy helpers and interactive parser behavior.
5. Add run summary artifact (`logs/playlist_run_*.log`) with effective timing sources.

## Operator Tip

Use this command before long runs:

```bash
./scripts/run_playlist.sh --print-playlist-plan true
```

It prints final sketch order and effective hold/timeout sources before any upload occurs.
