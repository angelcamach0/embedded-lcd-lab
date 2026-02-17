#pragma once

#include <Arduino.h>
#include <LiquidCrystal.h>

namespace lcdlab {

// Shared geometry and pin map used by all project sketches.
constexpr uint8_t kCols = 16;
constexpr uint8_t kRows = 2;
constexpr uint8_t kCells = kCols * kRows;

constexpr uint8_t kPinRs = 12;
constexpr uint8_t kPinE = 11;
constexpr uint8_t kPinD4 = 5;
constexpr uint8_t kPinD5 = 4;
constexpr uint8_t kPinD6 = 3;
constexpr uint8_t kPinD7 = 2;

inline bool isPrintableAscii(char c) {
  return (c >= 32 && c <= 126);
}

inline void beginDefault16x2(LiquidCrystal &lcd) {
  lcd.begin(kCols, kRows);
}

inline void drawCell(LiquidCrystal &lcd, uint8_t idx, char ch) {
  const uint8_t row = idx / kCols;
  const uint8_t col = idx % kCols;
  lcd.setCursor(col, row);
  lcd.print(ch);
}

inline void writeRow(LiquidCrystal &lcd, uint8_t row, const char *src, size_t len) {
  // Always write full row width to prevent stale characters from older frames.
  lcd.setCursor(0, row);
  for (uint8_t i = 0; i < kCols; i++) {
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

inline void copyClampedRow(char *dst, const char *src) {
  size_t i = 0;
  while (i < kCols && src[i] != '\0') {
    dst[i] = src[i];
    i++;
  }
  dst[i] = '\0';
}

}  // namespace lcdlab
