#include <LiquidCrystal.h>
#include <lcd_shared.h>

// RS, E, D4, D5, D6, D7
LiquidCrystal lcd(
  lcdlab::kPinRs, lcdlab::kPinE, lcdlab::kPinD4,
  lcdlab::kPinD5, lcdlab::kPinD6, lcdlab::kPinD7
);

const uint8_t COLS = lcdlab::kCols;
const uint8_t ROWS = lcdlab::kRows;
const uint16_t FRAMES_PER_CYCLE = 180;
const uint16_t FRAME_DELAY_MS = 110;
const uint16_t STARTUP_SETTLE_MS = 350;
const uint8_t STARTUP_WARMUP_FRAMES = 3;
const uint8_t STARTUP_PRIME_FRAMES = 2;
const uint16_t STARTUP_PRIME_DELAY_MS = 20;

// Per-column vertical position for a "drop"
int8_t dropRow[COLS];
uint16_t frameCounter = 0;
uint8_t warmupFrames = STARTUP_WARMUP_FRAMES;

char randomMatrixChar() {
  // Printable symbol-heavy range for a "matrix-like" effect.
  // Excludes space to keep display active.
  const char table[] =
      "0123456789"
      "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      "abcdefghijklmnopqrstuvwxyz"
      "!@#$%^&*()-_=+[]{};:,.<>?/|\\";
  return table[random(sizeof(table) - 1)];
}

void initDrops() {
  for (uint8_t c = 0; c < COLS; c++) {
    // Start each column at a random virtual row above/below screen.
    dropRow[c] = random(-3, 6);
  }
}

void drawNoiseBackground() {
  for (uint8_t r = 0; r < ROWS; r++) {
    for (uint8_t c = 0; c < COLS; c++) {
      lcd.setCursor(c, r);
      lcd.print(randomMatrixChar());
    }
  }
}

void updateDropHeads() {
  // Draw brighter "drop heads" after warmup to avoid first-frame flicker.
  for (uint8_t c = 0; c < COLS; c++) {
    if (warmupFrames == 0) {
      if (dropRow[c] >= 0 && dropRow[c] < ROWS) {
        lcd.setCursor(c, dropRow[c]);
        lcd.write(byte(255)); // Full block as "bright head"
      }
    }

    dropRow[c]++;

    // Reset drop after it passes below the screen.
    if (dropRow[c] > ROWS + random(0, 4)) {
      dropRow[c] = random(-4, 0);
    }
  }
}

void setup() {
  lcdlab::beginDefault16x2(lcd);
  // Small settle delay helps some LCD modules avoid first-frame artifacts.
  delay(STARTUP_SETTLE_MS);
  lcd.clear();
  Serial.begin(9600);

  // Seed randomness from a floating analog input.
  randomSeed(analogRead(A5));

  initDrops();

  // Prime a couple frames while display is hidden so first visible frame
  // appears stable after upload/reset.
  lcd.noDisplay();
  for (uint8_t i = 0; i < STARTUP_PRIME_FRAMES; i++) {
    drawNoiseBackground();
    delay(STARTUP_PRIME_DELAY_MS);
  }
  lcd.clear();
  lcd.display();
}

void loop() {
  // Each frame:
  // 1) redraw noisy background
  // 2) advance column heads
  // 3) emit done token when cycle budget reached
  drawNoiseBackground();
  updateDropHeads();

  if (warmupFrames > 0) {
    warmupFrames--;
  }

  frameCounter++;
  if (frameCounter >= FRAMES_PER_CYCLE) {
    // Host playlist script listens for this to move to next sketch.
    frameCounter = 0;
    Serial.println("PLAYLIST_DONE");
  }

  delay(FRAME_DELAY_MS);
}
