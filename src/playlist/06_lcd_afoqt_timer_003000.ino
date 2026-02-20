#include <LiquidCrystal.h>
#include <lcd_shared.h>

#include <ctype.h>
#include <stdio.h>
#include <string.h>

// RS, E, D4, D5, D6, D7
LiquidCrystal lcd(
  lcdlab::kPinRs, lcdlab::kPinE, lcdlab::kPinD4,
  lcdlab::kPinD5, lcdlab::kPinD6, lcdlab::kPinD7
);

namespace {

constexpr unsigned long kDefaultDurationSeconds = 30UL * 60UL;  // 00:30:00
constexpr unsigned long kTickMs = 1000UL;
constexpr unsigned long kSerialSilenceIdleMs = 5UL * 60UL * 1000UL;
constexpr size_t kInputMax = 64;

enum class TimerState : uint8_t {
  Idle = 0,
  Running = 1,
  Paused = 2,
  Done = 3
};

TimerState timerState = TimerState::Idle;
unsigned long initialSeconds = kDefaultDurationSeconds;
unsigned long remainingSeconds = kDefaultDurationSeconds;
unsigned long lastTickMs = 0UL;
unsigned long lastCommandMs = 0UL;

char serialBuf[kInputMax + 1];
size_t serialLen = 0;

void formatHhMmSs(unsigned long totalSeconds, char* out, size_t outLen) {
  // Keep LCD representation fixed-width HH:MM:SS.
  // Internal timer state can exceed 99h, but display is capped for stability.
  const unsigned long hoursRaw = totalSeconds / 3600UL;
  const unsigned long hours = (hoursRaw > 99UL) ? 99UL : hoursRaw;
  const unsigned long minutes = (totalSeconds % 3600UL) / 60UL;
  const unsigned long seconds = totalSeconds % 60UL;
  snprintf(out, outLen, "%02lu:%02lu:%02lu", hours, minutes, seconds);
}

void renderStatus(const char* top, const char* bottom) {
  lcdlab::writeRow(lcd, 0, top, strlen(top));
  lcdlab::writeRow(lcd, 1, bottom, strlen(bottom));
}

void renderTimer() {
  char row1[17];
  formatHhMmSs(remainingSeconds, row1, sizeof(row1));
  renderStatus("AFOQT TIMER", row1);
}

void renderIdle() {
  renderStatus("AFOQT TIMER", "IDLE");
}

void renderPaused() {
  char row1[17];
  formatHhMmSs(remainingSeconds, row1, sizeof(row1));
  renderStatus("AFOQT PAUSED", row1);
}

void renderDone() {
  renderStatus("AFOQT DONE", "00:00:00");
}

void ack(const char* verb) {
  Serial.print("ACK:TIMER|");
  Serial.println(verb);
}

void nack(const char* code) {
  Serial.print("NACK:TIMER|");
  Serial.println(code);
}

bool parseUnsigned(const char* s, unsigned long* out) {
  // PRE: s is a null-terminated string; out is a valid pointer.
  // POST: returns true and stores parsed value if input is digits-only.
  if (s == nullptr || *s == '\0') {
    return false;
  }
  unsigned long v = 0UL;
  for (size_t i = 0; s[i] != '\0'; i++) {
    if (!isdigit(static_cast<unsigned char>(s[i]))) {
      return false;
    }
    v = v * 10UL + static_cast<unsigned long>(s[i] - '0');
  }
  *out = v;
  return true;
}

bool parseHhMmSs(const char* s, unsigned long* outSeconds) {
  // PRE: s is a null-terminated candidate HHMMSS string.
  // POST: returns true only for valid bounded HHMMSS and sets outSeconds.
  if (s == nullptr || strlen(s) != 6) {
    return false;
  }
  for (size_t i = 0; i < 6; i++) {
    if (!isdigit(static_cast<unsigned char>(s[i]))) {
      return false;
    }
  }

  const unsigned long hh = static_cast<unsigned long>((s[0] - '0') * 10 + (s[1] - '0'));
  const unsigned long mm = static_cast<unsigned long>((s[2] - '0') * 10 + (s[3] - '0'));
  const unsigned long ss = static_cast<unsigned long>((s[4] - '0') * 10 + (s[5] - '0'));
  if (mm > 59UL || ss > 59UL) {
    return false;
  }

  *outSeconds = (hh * 3600UL) + (mm * 60UL) + ss;
  return true;
}

void startWithSeconds(unsigned long seconds) {
  // PRE: seconds is already validated by caller.
  // POST:
  // - timer state transitions to Running or Done.
  // - render updates LCD to the corresponding state.
  initialSeconds = seconds;
  remainingSeconds = seconds;
  lastTickMs = millis();
  lastCommandMs = lastTickMs;
  timerState = (seconds == 0UL) ? TimerState::Done : TimerState::Running;
  if (timerState == TimerState::Done) {
    renderDone();
    Serial.println("PLAYLIST_DONE");
  } else {
    renderTimer();
  }
}

void handleTimerCommand(char* line) {
  // PRE: line is mutable, null-terminated, newline-stripped command frame.
  // POST:
  // - recognized commands update timer state deterministically.
  // - malformed commands emit NACK without crashing loop.
  constexpr const char* kPrefix = "CMD:TIMER|";
  if (strncmp(line, kPrefix, strlen(kPrefix)) != 0) {
    return;
  }

  char* rest = line + strlen(kPrefix);
  char* save = nullptr;
  char* verb = strtok_r(rest, "|", &save);
  if (verb == nullptr) {
    nack("BAD_FORMAT");
    return;
  }

  if (strcmp(verb, "START") == 0) {
    char* mode = strtok_r(nullptr, "|", &save);
    char* value = strtok_r(nullptr, "|", &save);
    char* extra = strtok_r(nullptr, "|", &save);
    if (mode == nullptr || value == nullptr || extra != nullptr) {
      nack("BAD_FORMAT");
      return;
    }

    unsigned long seconds = 0UL;
    bool ok = false;
    if (strcmp(mode, "SECONDS") == 0) {
      ok = parseUnsigned(value, &seconds);
    } else if (strcmp(mode, "HHMMSS") == 0) {
      ok = parseHhMmSs(value, &seconds);
    } else {
      nack("BAD_MODE");
      return;
    }

    if (!ok) {
      nack("BAD_RANGE");
      return;
    }

    startWithSeconds(seconds);
    ack("START");
    return;
  }

  if (strcmp(verb, "PAUSE") == 0) {
    if (timerState == TimerState::Running) {
      timerState = TimerState::Paused;
      lastCommandMs = millis();
      renderPaused();
    }
    ack("PAUSE");
    return;
  }

  if (strcmp(verb, "RESUME") == 0) {
    if (timerState == TimerState::Paused) {
      timerState = TimerState::Running;
      lastTickMs = millis();
      lastCommandMs = lastTickMs;
      renderTimer();
    }
    ack("RESUME");
    return;
  }

  if (strcmp(verb, "RESET") == 0) {
    startWithSeconds(initialSeconds);
    ack("RESET");
    return;
  }

  if (strcmp(verb, "STOP") == 0) {
    timerState = TimerState::Idle;
    lastCommandMs = millis();
    renderIdle();
    ack("STOP");
    return;
  }

  if (strcmp(verb, "PING") == 0) {
    lastCommandMs = millis();
    ack("PING");
    return;
  }

  nack("BAD_VERB");
}

void processSerial() {
  // PRE: Serial has been initialized in setup().
  // POST:
  // - consumes available bytes.
  // - executes complete '\n'-delimited commands.
  // - drops oversized frames safely.
  while (Serial.available() > 0) {
    char c = static_cast<char>(Serial.read());
    if (c == '\r') {
      continue;
    }
    if (c == '\n') {
      serialBuf[serialLen] = '\0';
      if (serialLen > 0) {
        handleTimerCommand(serialBuf);
      }
      serialLen = 0;
      continue;
    }
    if (serialLen < kInputMax) {
      if (lcdlab::isPrintableAscii(c)) {
        serialBuf[serialLen++] = c;
      }
    } else {
      // Safety: drop oversized frame to avoid partial command execution.
      serialLen = 0;
      nack("INPUT_OVERFLOW");
    }
  }
}

void tickTimer() {
  // PRE: called from loop() frequently.
  // POST:
  // - decrements by elapsed whole seconds in Running state.
  // - emits PLAYLIST_DONE exactly once on terminal transition to Done.
  if (timerState != TimerState::Running) {
    return;
  }

  const unsigned long now = millis();
  if (now - lastTickMs < kTickMs) {
    return;
  }

  while (remainingSeconds > 0UL && (now - lastTickMs) >= kTickMs) {
    remainingSeconds--;
    lastTickMs += kTickMs;
  }

  if (remainingSeconds == 0UL) {
    timerState = TimerState::Done;
    renderDone();
    Serial.println("PLAYLIST_DONE");
    return;
  }

  renderTimer();
}

void enforceSerialSilenceFallback() {
  // PRE: lastCommandMs tracks latest command/heartbeat event.
  // POST: paused timer can re-enter Idle after silence threshold.
  // NOTE:
  // - Running timers are intentionally excluded so long exams are not cut
  //   short when no further serial commands are sent from the host.
  if (timerState != TimerState::Paused) {
    return;
  }
  const unsigned long now = millis();
  if ((now - lastCommandMs) >= kSerialSilenceIdleMs) {
    timerState = TimerState::Idle;
    renderIdle();
    nack("SERIAL_TIMEOUT");
  }
}

}  // namespace

void setup() {
  Serial.begin(9600);
  lcdlab::beginDefault16x2(lcd);
  lcd.clear();
  lastCommandMs = millis();
  renderIdle();
}

void loop() {
  processSerial();
  tickTimer();
  enforceSerialSilenceFallback();
}
