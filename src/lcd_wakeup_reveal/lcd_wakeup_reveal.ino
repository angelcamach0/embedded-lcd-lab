#include <LiquidCrystal.h>

// HD44780 16x2 in 4-bit mode:
// constructor order = RS, E, D4, D5, D6, D7
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

// Physical LCD dimensions (used by all indexing math).
const uint8_t COLS = 16;
const uint8_t ROWS = 2;
const uint8_t CELLS = COLS * ROWS;

// ------------------------------------------------------------------
// MESSAGE SETUP (user-editable)
// ------------------------------------------------------------------
// 1) Set how many messages to use from MESSAGES[].
// 2) Add lines by copy/paste.
// 3) Use '\n' to start second row.
// 4) Max visible chars per message across full screen = 32.
//
// Example to add one:
// - Increase ACTIVE_MESSAGE_COUNT
// - Add a new line in MESSAGES[]
const uint8_t ACTIVE_MESSAGE_COUNT = 4;
const char *MESSAGES[] = {
    "Wake up\nangelcamach0",
    "follow the white rabbit",
    "and I will show you how",
    "there is no\nspoon",
//    "Wake up\nangelcamach0",
//    "follow the white rabbit",
//    "and I will show you how",
//    "deep the\nhole goes",
};
// ------------------------------------------------------------------

// Animation controls.
// ENABLE_TRAILING_DOTS:
// - true: reveal -> pause -> append dots -> hold -> clear -> next message
// - false: reveal -> short hold -> clear -> next message
const bool ENABLE_TRAILING_DOTS = true;
const uint16_t POST_REVEAL_PAUSE_MS = 3000;
const uint16_t DOT_STEP_MS = 1500;
const uint16_t POST_DOTS_HOLD_MS = 5000;

// Used only when trailing dots are disabled.
const uint16_t POST_REVEAL_HOLD_MS = 1800; // used only when dots are disabled

// targetGrid is the current message mapped to 32 screen cells.
// It is the single source of truth for reveal/clear phases.
char targetGrid[CELLS + 1];
int8_t messageEndIdx = -1;   // last non-space cell, for dot insertion start
uint8_t currentMessageIndex = 0; // which message should render this loop cycle

// Returns one random printable symbol used for matrix noise frames.
char randomGlyph() {
  const char glyphs[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      "abcdefghijklmnopqrstuvwxyz"
      "0123456789"
      "!@#$%^&*()-_=+[]{};:,.<>?/|\\";
  return glyphs[random(sizeof(glyphs) - 1)];
}

// Converts linear index [0..31] -> (row, col), then prints one character.
// Keeping this in one place prevents duplicated row/column math bugs.
void drawCell(uint8_t idx, char ch) {
  uint8_t row = idx / COLS;
  uint8_t col = idx % COLS;
  lcd.setCursor(col, row);
  lcd.print(ch);
}

// Fills all cells with random symbols for "matrix noise".
// This is used as the visual baseline before characters lock in.
void drawMatrixNoise() {
  for (uint8_t i = 0; i < CELLS; i++) {
    drawCell(i, randomGlyph());
  }
}

// Fisher-Yates in-place shuffle.
// Used to randomize reveal order and clear order so effects feel organic.
void shuffle(uint8_t *arr, uint8_t n) {
  for (uint8_t i = n - 1; i > 0; i--) {
    uint8_t j = random(i + 1);
    uint8_t t = arr[i];
    arr[i] = arr[j];
    arr[j] = t;
  }
}

// Maps a user message into the fixed 32-cell grid:
// - starts with all spaces
// - copies chars left->right
// - '\n' jumps writer to second row start
// - overflow is truncated cleanly
//
// This lets animation code be message-agnostic; it only reads targetGrid.
void buildTargetGrid(const char *msg) {
  // Start with a clean, fully blank frame.
  for (uint8_t i = 0; i < CELLS; i++) {
    targetGrid[i] = ' ';
  }
  targetGrid[CELLS] = '\0';
  messageEndIdx = -1;

  uint8_t idx = 0;
  for (uint8_t i = 0; msg[i] != '\0'; i++) {
    char ch = msg[i];

    if (ch == '\n') {
      // Hard row break: next char lands at row 2, col 0.
      idx = COLS;
      continue;
    }

    if (idx >= CELLS) {
      break; // prevent write past display capacity
    }

    targetGrid[idx++] = ch;
    // Track last non-space write position so dots can append from there.
    messageEndIdx = idx - 1;
  }
}

// True if message contains any visible character.
// We skip whitespace-only messages so users can leave placeholders in MESSAGES[].
bool hasText(const char *msg) {
  for (uint8_t i = 0; msg[i] != '\0'; i++) {
    if (msg[i] != ' ' && msg[i] != '\n' && msg[i] != '\t' && msg[i] != '\r') {
      return true;
    }
  }
  return false;
}

// Picks the active message for this cycle:
// - clamps ACTIVE_MESSAGE_COUNT to actual array size
// - keeps currentMessageIndex in range
// - skips empty/whitespace-only message entries
//
// Returns "" if no active message has visible text.
const char *getCurrentMessage() {
  const uint8_t totalMessages = sizeof(MESSAGES) / sizeof(MESSAGES[0]);
  const uint8_t useCount = (ACTIVE_MESSAGE_COUNT <= totalMessages)
                               ? ACTIVE_MESSAGE_COUNT
                               : totalMessages;

  if (useCount == 0) {
    return "";
  }

  // Guard against runtime config edits.
  if (currentMessageIndex >= useCount) {
    currentMessageIndex = 0;
  }

  // Search circularly from current index until we find visible text.
  for (uint8_t i = 0; i < useCount; i++) {
    uint8_t idx = (currentMessageIndex + i) % useCount;
    if (hasText(MESSAGES[idx])) {
      currentMessageIndex = idx;
      return MESSAGES[idx];
    }
  }

  // All active messages are empty.
  return "";
}

// Advances to next message slot inside active range.
// Does not care whether next slot is empty; getCurrentMessage() will skip empties.
void advanceMessageIndex() {
  const uint8_t totalMessages = sizeof(MESSAGES) / sizeof(MESSAGES[0]);
  const uint8_t useCount = (ACTIVE_MESSAGE_COUNT <= totalMessages)
                               ? ACTIVE_MESSAGE_COUNT
                               : totalMessages;
  if (useCount == 0) {
    currentMessageIndex = 0;
    return;
  }
  currentMessageIndex = (currentMessageIndex + 1) % useCount;
}

// Appends up to 3 dots right after message end.
// Dots are only written into currently empty cells, never overwriting text.
// This function mutates targetGrid so frame state remains coherent.
void appendTrailingDots() {
  // No visible message -> nothing to append.
  if (messageEndIdx < 0) {
    return;
  }

  uint8_t dotsPlaced = 0;
  uint8_t pos = (uint8_t)(messageEndIdx + 1);

  while (dotsPlaced < 3 && pos < CELLS) {
    // Preserve message chars; only consume empty cells.
    if (targetGrid[pos] == ' ') {
      targetGrid[pos] = '.';
      drawCell(pos, '.');
      dotsPlaced++;
      delay(DOT_STEP_MS);
    }
    pos++;
  }
}

// Runs full reveal pipeline for current targetGrid:
// Phase 0) all cells noise
// Phase 1) message characters lock in random order
// Phase 2) non-message cells clear in random order
// Final) hard sanitize to guarantee only message text remains visible
void revealMessage() {
  uint8_t letterIdx[CELLS];
  uint8_t emptyIdx[CELLS];
  uint8_t letterCount = 0;
  uint8_t emptyCount = 0;

  // Partition cell indices once; later phases operate on these lists.
  for (uint8_t i = 0; i < CELLS; i++) {
    if (targetGrid[i] == ' ') {
      emptyIdx[emptyCount++] = i;
    } else {
      letterIdx[letterCount++] = i;
    }
  }

  shuffle(letterIdx, letterCount);
  shuffle(emptyIdx, emptyCount);

  bool locked[CELLS] = {false};
  bool cleared[CELLS] = {false};

  // Phase 0: establish full matrix look before any letter is trusted.
  for (uint8_t f = 0; f < 12; f++) {
    drawMatrixNoise();
    delay(70);
  }

  // Phase 1: lock one message character at a time in random slot order.
  // Between each lock, render jitter frames so unrevealed cells keep moving.
  for (uint8_t r = 0; r < letterCount; r++) {
    uint8_t lockPos = letterIdx[r];
    locked[lockPos] = true;

    for (uint8_t frame = 0; frame < 7; frame++) {
      for (uint8_t i = 0; i < CELLS; i++) {
        if (locked[i]) {
          drawCell(i, targetGrid[i]);
        } else {
          drawCell(i, randomGlyph());
        }
      }
      delay(65);
    }
  }

  // Phase 2: after full reveal, clear empty cells progressively.
  // cleared[] ensures already-cleared cells stay blank in later frames.
  for (uint8_t c = 0; c < emptyCount; c++) {
    uint8_t clearPos = emptyIdx[c];
    drawCell(clearPos, ' ');

    // Render one frame with:
    // - letters fixed
    // - this step's clearPos blank
    // - previously cleared cells blank
    // - not-yet-cleared empties still noisy
    for (uint8_t i = 0; i < CELLS; i++) {
      if (targetGrid[i] != ' ') {
        drawCell(i, targetGrid[i]);
      } else if (i == clearPos) {
        drawCell(i, ' ');
      } else if (cleared[i]) {
        drawCell(i, ' ');
      } else {
        drawCell(i, randomGlyph());
      }
    }
    cleared[clearPos] = true;
    delay(55);
  }

  // Final sanitize pass: deterministic end frame (no leftover noise).
  for (uint8_t i = 0; i < CELLS; i++) {
    if (targetGrid[i] == ' ') {
      drawCell(i, ' ');
    } else {
      drawCell(i, targetGrid[i]);
    }
  }
}

void setup() {
  // Hardware init.
  lcd.begin(COLS, ROWS);
  lcd.clear();
  Serial.begin(9600);

  // Seed PRNG from floating analog pin for non-repeating randomness.
  randomSeed(analogRead(A5));
}

void loop() {
  // 1) Pick current message from configured set.
  const char *activeMessage = getCurrentMessage();

  // 2) Build fresh grid each cycle so previous loop's dots/noise are reset.
  buildTargetGrid(activeMessage);

  // 3) Run matrix reveal pipeline.
  revealMessage();

  // 4) Optional dot post-effect and hold timing.
  if (ENABLE_TRAILING_DOTS) {
    delay(POST_REVEAL_PAUSE_MS);
    appendTrailingDots();
    delay(POST_DOTS_HOLD_MS);
  } else {
    delay(POST_REVEAL_HOLD_MS);
  }

  // 5) Visual reset before next message cycle.
  lcd.clear();
  delay(500);

  // 6) Move sequencer forward.
  advanceMessageIndex();

  // Emit done token after full message set completes one full round.
  // This is consumed by scripts/run_playlist.sh when WAIT_FOR_DONE=true.
  if (currentMessageIndex == 0) {
    Serial.println("PLAYLIST_DONE");
  }
}
