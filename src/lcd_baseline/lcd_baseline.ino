#include <LiquidCrystal.h>

// RS, E, D4, D5, D6, D7
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

void setup() {
  // Minimal sanity sketch to validate power, contrast, and pin mapping.
  lcd.begin(16, 2);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("HELLO");
  lcd.setCursor(0, 1);
  lcd.print("LCD baseline OK");
}

void loop() {
}
