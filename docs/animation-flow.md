# LCD Wakeup Reveal - Animation Flow

## Purpose

This sketch renders a matrix-style reveal animation on a 16x2 HD44780 LCD, then optionally appends trailing dots and rotates through a configurable message list.

## Core Data Model

1. `MESSAGES[]`
- User-provided message list.
- Supports `\n` to force second-row placement.

2. `targetGrid[32]`
- Canonical frame state for current message.
- Row-major mapping of all display cells.
- Message chars are fixed targets; empty cells are spaces.

3. `messageEndIdx`
- Last non-space index in `targetGrid`.
- Starting point for trailing-dot insertion.

4. `currentMessageIndex`
- Sequence cursor for message rotation.

## Message Selection Logic

1. Clamp `ACTIVE_MESSAGE_COUNT` to available list size.
2. Skip empty/whitespace-only message entries.
3. Return `""` if all active entries are empty.
4. Advance index each loop to cycle through configured messages.

## Grid Build Logic (`buildTargetGrid`)

1. Initialize all 32 cells to spaces.
2. Copy message chars left-to-right.
3. On `\n`, jump write index to second-row start (`idx = 16`).
4. Truncate cleanly if content exceeds 32 visible cells.

## Animation Pipeline (`revealMessage`)

### Phase 0 - Full Matrix Noise
- All 32 cells rendered as random glyphs.
- Establishes dynamic "encrypted" baseline.

### Phase 1 - Random Character Lock-In
- Compute `letterIdx[]` from non-space cells.
- Shuffle reveal order (Fisher-Yates).
- Lock one letter position at a time.
- Between locks, render jitter frames:
  - locked cells show final target char
  - unlocked cells keep random noise

### Phase 2 - Progressive Empty-Cell Clear
- Compute `emptyIdx[]` for non-message cells.
- Shuffle clear order.
- Clear one empty cell per step while preserving:
  - message letters as fixed
  - previously cleared empties as blank
  - remaining empties as noise

### Final Sanitize Pass
- Deterministic final frame:
  - message cells = target chars
  - non-message cells = spaces

## Trailing Dot Effect (`appendTrailingDots`)

Enabled via `ENABLE_TRAILING_DOTS`.

1. Wait `POST_REVEAL_PAUSE_MS` after reveal.
2. Starting after `messageEndIdx`, place up to 3 dots.
3. Place one dot every `DOT_STEP_MS`.
4. Do not overwrite message characters.
5. Hold final frame for `POST_DOTS_HOLD_MS`.

If disabled:
- Use `POST_REVEAL_HOLD_MS` instead.

## Timing Controls

- `POST_REVEAL_PAUSE_MS`: delay before adding dots
- `DOT_STEP_MS`: delay between each dot
- `POST_DOTS_HOLD_MS`: hold after full dots
- `POST_REVEAL_HOLD_MS`: hold when dots disabled

## Why This Structure Scales

1. Message content and animation are separated.
2. Any message can be introduced by editing data only.
3. Multi-message support is sequence-driven, not hardcoded logic per phrase.
4. Frame construction is deterministic at key boundaries (sanitized end state).

## Customization Points

1. `MESSAGES[]` and `ACTIVE_MESSAGE_COUNT`
2. Glyph set in `randomGlyph()`
3. Phase pacing constants (loop delays)
4. Dot behavior toggle and timing

## Known Constraints

1. Display is fixed 16x2 (32 visible chars).
2. UTF-8/non-ASCII symbols may not render as expected on HD44780 charset.
3. Longer text is truncated to fit display capacity.

## See also

1. `../src/playlist/03_lcd_wakeup_reveal_030.ino` implementation reference (current default filename)
2. `codeflows/src_lcd_wakeup_reveal.md` per-file flow diagram
3. `FUTURE_IDEAS_AND_IMPLEMENTATION_PLAN.md` for planned dynamic LCD-size support
4. `INDEX.md` for full documentation navigation
