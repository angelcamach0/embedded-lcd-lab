# Timing Strategy Risks and Tradeoffs

This document explains risks of filename-only timing and why runtime overrides were added as an optional layer.

## Baseline strategy

Default behavior remains:
1. Runtime is inferred from sketch filename suffix `_HHMMSS`.

Example:
1. `03_lcd_wakeup_reveal_000030.ino` -> 30 seconds
2. `04_lcd_city_datetime_temp_feed_003000.ino` -> 30 minutes

## Risks of filename-only timing

1. Rename fragility
   - Renaming files during active runs can cause stale in-memory paths and load failures.
2. Operational friction
   - Every timing tweak requires a file rename.
3. Repository noise
   - Timing-only experiments generate rename diffs unrelated to logic.
4. Human error
   - A malformed suffix can produce unexpected runtime.
5. Collaboration drift
   - Team members may carry different filename timing variants for same sketch logic.

## Why runtime override helps

1. Supports rapid timing experiments without touching filenames.
2. Keeps source files stable while tuning study/test timing.
3. Reduces rename-driven merge conflicts in shared branches.

## Override model

Filename timing stays default unless explicit override is provided.

Precedence:
1. Explicit targeted override (`--override-index` or `--override-sketch`)
2. Explicit global override (`--duration-override-hhmmss`)
3. Filename `_HHMMSS`
4. Script fallback defaults

## Guardrails

1. Override input must be valid `HHMMSS` with `MM <= 59`, `SS <= 59`.
2. `--override-index` and `--override-sketch` are mutually exclusive.
3. If override parsing fails, script exits with a clear error.
4. If no override target matches, default behavior remains intact.

## Recommendation

1. Keep `_HHMMSS` as canonical default for predictable out-of-box behavior.
2. Use runtime override flags for temporary runs, practice sessions, and rapid iteration.
3. Rename files only when you intentionally want new default timing checked into git.

