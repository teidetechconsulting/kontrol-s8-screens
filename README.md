# Kontrol S8 Screens (QML)

Phrase-oriented deck screens for the Traktor Kontrol S8 in Mixxx 2.6, rendered
by Mixxx's QML controller screens and sent over the S8's bulk interface (IF6,
EP 0x04). Use together with the Kontrol S8 HID mapping (controls, LEDs, stems).

Needs Mixxx 2.6 built with `-DQML=ON`.

| File | |
|---|---|
| `Kontrol-S8-Screens.bulk.xml` | mapping: two 480x272 RGB565 (big-endian) screens |
| `KontrolS8Screen.qml` | the screen: header, status, Mixxx waveform, phrase timeline, next cue, and the S8 frame encoder (inline: Mixxx loads screen QML from its own qml dir, so relative imports don't resolve) |
| `test/s8frame.test.mjs` | `node test/s8frame.test.mjs`: tests the encoder extracted from the QML file |

Frame format from [kontrol-s8-protocol](https://github.com/gusgustavodj/kontrol-s8-protocol) (CC-BY-4.0).

Bars count from the first beat of the beat grid (Mixxx has no downbeat
detection); phrases default to 16 bars (controller setting `phraseBars`).
