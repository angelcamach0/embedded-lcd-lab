#include <LiquidCrystal.h>
#include <lcd_shared.h>

// RS, E, D4, D5, D6, D7
LiquidCrystal lcd(
  lcdlab::kPinRs, lcdlab::kPinE, lcdlab::kPinD4,
  lcdlab::kPinD5, lcdlab::kPinD6, lcdlab::kPinD7
);

void setup() {
  // Minimal sanity sketch to validate power, contrast, and pin mapping.
  lcdlab::beginDefault16x2(lcd);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("HELLO");
  lcd.setCursor(0, 1);
  lcd.print("LCD baseline OK");
}

void loop() {
}
