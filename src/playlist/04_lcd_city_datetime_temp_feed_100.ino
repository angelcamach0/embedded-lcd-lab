#include <LiquidCrystal.h>
#include <string.h>
#include <lcd_shared.h>

// HD44780 16x2 in 4-bit mode: RS, E, D4, D5, D6, D7
LiquidCrystal lcd(
  lcdlab::kPinRs, lcdlab::kPinE, lcdlab::kPinD4,
  lcdlab::kPinD5, lcdlab::kPinD6, lcdlab::kPinD7
);

const uint8_t COLS = lcdlab::kCols;
const uint8_t ROWS = lcdlab::kRows;
const size_t INPUT_MAX = 64;

char inputLine[INPUT_MAX + 1];
size_t inputLen = 0;
char currentLine1[COLS + 1];
char currentLine2[COLS + 1];

void renderDisplay() {
  // Render from stable "current" buffers so partial serial lines do not flicker.
  lcdlab::writeRow(lcd, 0, currentLine1, strlen(currentLine1));
  lcdlab::writeRow(lcd, 1, currentLine2, strlen(currentLine2));
}

void showText(const char *payload) {
  // Parse "line1|line2" in-place using fixed buffers.
  char line1[COLS + 1];
  char line2[COLS + 1];
  size_t l1 = 0;
  size_t l2 = 0;
  bool secondLine = false;

  memset(line1, 0, sizeof(line1));
  memset(line2, 0, sizeof(line2));

  for (size_t i = 0; payload[i] != '\0'; i++) {
    char c = payload[i];
    if (c == '|') {
      // First delimiter splits row1 and row2.
      secondLine = true;
      continue;
    }
    if (!secondLine) {
      if (l1 < COLS) {
        line1[l1++] = c;
      }
    } else {
      if (l2 < COLS) {
        line2[l2++] = c;
      }
    }
  }

  lcdlab::copyClampedRow(currentLine1, line1);
  lcdlab::copyClampedRow(currentLine2, line2);
  renderDisplay();
}

void setup() {
  lcdlab::beginDefault16x2(lcd);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Waiting serial");
  lcd.setCursor(0, 1);
  lcd.print("feed...");

  Serial.begin(9600);
  // Initialize parser + render buffers.
  memset(inputLine, 0, sizeof(inputLine));
  inputLen = 0;
  lcdlab::copyClampedRow(currentLine1, "Waiting serial");
  lcdlab::copyClampedRow(currentLine2, "feed...");
}

void loop() {
  // Read serial incrementally and render only on newline-delimited payloads.
  // Expected format from host: "line1|line2\n".
  while (Serial.available() > 0) {
    char c = (char)Serial.read();

    if (c == '\n') {
      if (inputLen > 0) {
        inputLine[inputLen] = '\0';
        showText(inputLine);
      }
      inputLen = 0;
      inputLine[0] = '\0';
    } else if (c != '\r' && lcdlab::isPrintableAscii(c)) {
      if (inputLen < INPUT_MAX) {
        inputLine[inputLen++] = c;
      } else {
        // Reset on overflow to avoid stale/partial frame rendering.
        inputLen = 0;
        inputLine[0] = '\0';
      }
    }
  }
}
