#include <LiquidCrystal.h>
#include <string.h>

// HD44780 16x2 in 4-bit mode: RS, E, D4, D5, D6, D7
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

const uint8_t COLS = 16;
const uint8_t ROWS = 2;
const size_t INPUT_MAX = 64;

char inputLine[INPUT_MAX + 1];
size_t inputLen = 0;
char currentLine1[COLS + 1];
char currentLine2[COLS + 1];

bool isPrintableAscii(char c) {
  // HD44780 custom charset can behave inconsistently for extended bytes.
  // Restricting to printable ASCII avoids random glyph artifacts.
  return (c >= 32 && c <= 126);
}

void writeRow(uint8_t row, const char *src, size_t len) {
  // Always write full 16 columns so old characters do not linger when the new
  // payload is shorter than the previous frame.
  lcd.setCursor(0, row);
  for (uint8_t i = 0; i < COLS; i++) {
    char out = ' ';
    if (i < len) {
      out = src[i];
      if (!isPrintableAscii(out)) {
        out = ' ';
      }
    }
    lcd.write(out);
  }
}

void copyClamped(char *dst, const char *src) {
  // Bounded copy into fixed 16-char LCD row buffers.
  size_t i = 0;
  while (i < COLS && src[i] != '\0') {
    dst[i] = src[i];
    i++;
  }
  dst[i] = '\0';
}

void renderDisplay() {
  // Render from stable "current" buffers so partial serial lines do not flicker.
  writeRow(0, currentLine1, strlen(currentLine1));
  writeRow(1, currentLine2, strlen(currentLine2));
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

  copyClamped(currentLine1, line1);
  copyClamped(currentLine2, line2);
  renderDisplay();
}

void setup() {
  lcd.begin(COLS, ROWS);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Waiting serial");
  lcd.setCursor(0, 1);
  lcd.print("feed...");

  Serial.begin(9600);
  // Initialize parser + render buffers.
  memset(inputLine, 0, sizeof(inputLine));
  inputLen = 0;
  copyClamped(currentLine1, "Waiting serial");
  copyClamped(currentLine2, "feed...");
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
    } else if (c != '\r' && isPrintableAscii(c)) {
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
