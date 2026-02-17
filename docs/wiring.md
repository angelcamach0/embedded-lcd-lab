# 16x2 LCD Wiring (4-bit mode)

## LCD -> Arduino Uno

1. VSS -> GND
2. VDD -> 5V
3. VO -> GND (quick test only) or potentiometer wiper (recommended)
4. RS -> D12
5. RW -> GND
6. E -> D11
7. D4 -> D5
8. D5 -> D4
9. D6 -> D3
10. D7 -> D2
11. A (pin 15) -> 5V (prefer ~220 ohm resistor)
12. K (pin 16) -> GND

## Notes

- D0-D3 are unused in 4-bit mode.
- Missing `K -> GND` causes backlight/display visibility issues.
- Either Arduino GND pin can be used; all GND pins are common.
- For cleaner/safer wiring:
1. Use a 10k potentiometer for `VO` contrast control:
   - one side to 5V
   - one side to GND
   - center pin to `VO`
2. Use ~220 ohm resistor in series with `A` (LCD backlight anode).

## See also

1. `REPLICATION_REQUIREMENTS.md` for hardware/software prerequisites
2. `LESSONS_LEARNED.md` for wiring-related failure patterns
3. `INDEX.md` for documentation navigation
