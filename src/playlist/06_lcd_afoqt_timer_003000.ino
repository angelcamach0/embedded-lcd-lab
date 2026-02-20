#include <LiquidCrystal.h>
#include <lcd_shared.h>

// RS, E, D4, D5, D6, D7
LiquidCrystal lcd(
  lcdlab::kPinRs, lcdlab::kPinE, lcdlab::kPinD4,
  lcdlab::kPinD5, lcdlab::kPinD6, lcdlab::kPinD7
);

namespace {

constexpr unsigned long kDefaultDurationSeconds = 30UL * 60UL;  // 00:30:00
constexpr unsigned long kTickMs = 1000UL;

unsigned long remainingSeconds = kDefaultDurationSeconds;
unsigned long lastTickMs = 0UL;
bool timerDone = false;

void formatHhMmSs(unsigned long totalSeconds, char* out, size_t outLen) {
  const unsigned long hours = totalSeconds / 3600UL;
  const unsigned long minutes = (totalSeconds % 3600UL) / 60UL;
  const unsigned long seconds = totalSeconds % 60UL;
  snprintf(out, outLen, "%02lu:%02lu:%02lu", hours, minutes, seconds);
}

void renderTimer() {
  char row0[17];
  char row1[17];

  snprintf(row0, sizeof(row0), "AFOQT COUNTDOWN");
  formatHhMmSs(remainingSeconds, row1, sizeof(row1));

  lcdlab::writeRow(lcd, 0, row0, strlen(row0));
  lcdlab::writeRow(lcd, 1, row1, strlen(row1));
}

void renderDone() {
  const char* row0 = "AFOQT COUNTDOWN";
  const char* row1 = "00:00:00 DONE";
  lcdlab::writeRow(lcd, 0, row0, strlen(row0));
  lcdlab::writeRow(lcd, 1, row1, strlen(row1));
}

}  // namespace

void setup() {
  lcdlab::beginDefault16x2(lcd);
  lcd.clear();
  renderTimer();
  lastTickMs = millis();
}

void loop() {
  if (timerDone) {
    return;
  }

  const unsigned long now = millis();
  if (now - lastTickMs < kTickMs) {
    return;
  }

  // Advance in one-second steps while handling occasional loop jitter.
  while (remainingSeconds > 0UL && (now - lastTickMs) >= kTickMs) {
    remainingSeconds--;
    lastTickMs += kTickMs;
  }

  if (remainingSeconds == 0UL) {
    timerDone = true;
    renderDone();
    Serial.begin(9600);
    Serial.println("PLAYLIST_DONE");
    return;
  }

  renderTimer();
}

