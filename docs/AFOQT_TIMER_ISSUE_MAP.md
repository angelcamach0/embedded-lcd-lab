# AFOQT Timer Issue Map

This file tracks the AFOQT LCD timer feature breakdown into focused issues and branches.

## Duration Note

`_003000` in the current `_HHMMSS` convention means `00:30:00` (30 minutes).

## Issues and Branches

1. Issue #1: Implement LCD AFOQT countdown timer (HH:MM:SS)  
   Branch: `feature/issue-1-lcd-afoqt-countdown`
2. Issue #2: Define serial input contract for LCD AFOQT timer  
   Branch: `feature/issue-2-serial-contract`
3. Issue #3: Implement Arduino countdown core (HH:MM:SS display loop)  
   Branch: `feature/issue-3-arduino-countdown-core`
4. Issue #4: Integrate master script timer as source of truth  
   Branch: `feature/issue-4-host-source-of-truth`
5. Issue #5: Support duration extraction from sketch naming convention (`_HHMMSS`)  
   Branch: `feature/issue-5-hhmmss-duration-integration`
6. Issue #6: Add timer safety and validation behavior  
   Branch: `feature/issue-6-timer-validation-safety`
7. Issue #7: Define clean exit and idle behavior for timer mode  
   Branch: `feature/issue-7-exit-idle-behavior`
8. Issue #8: Add optional runtime override flag for per-sketch duration  
   Branch: `feature/issue-8-duration-override-flag`
9. Issue #9: Add sketch-targeted override selection UX in `run_playlist.sh`  
   Branch: `feature/issue-9-sketch-override-selection`
10. Issue #10: Document risks and tradeoffs of filename-only timing vs runtime overrides  
    Branch: `feature/issue-10-timing-risk-docs`

## Design Decision: Keep Filename Default, Add Override

Default behavior should stay the same:
1. Read timing from filename suffix `_HHMMSS`.

Optional behavior:
1. User can override runtime duration via CLI flags without renaming files.

This keeps backward compatibility and avoids forcing file renames for every timing experiment.

## Risks If Timing Depends Only on File Names

1. Rename fragility: changing filenames while running can break active playlist references.
2. Operational friction: users must rename files for every timing tweak.
3. Review noise: timing-only changes create git diffs that look like content changes.
4. Human error: wrong suffix can silently produce wrong runtime.
5. Repro issues: collaborators may use same sketch text with different filename timing.

## Recommended Override Model

Precedence:
1. Explicit per-sketch override (if provided)
2. Filename `_HHMMSS`
3. Script fallback default

Implementation idea:
1. Add flag for direct override value: `--duration-override-hhmmss HHMMSS`
2. Add flag to target a specific sketch:
   - by discovered index: `--override-index N`
   - or by exact basename: `--override-sketch NAME.ino`
3. Apply override in `run_playlist.sh` right before selecting hold/timeout for the current sketch.
4. If override target does not match, keep standard filename-based timing.

