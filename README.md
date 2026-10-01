# Kontrol S8 Screens (QML)

Phrase-oriented deck screens for the Traktor Kontrol S8 in Mixxx 2.6, rendered
by Mixxx's QML controller screens and sent over the S8's bulk interface (IF6,
EP 0x04). Use together with the Kontrol S8 HID mapping (controls, LEDs, stems).

Needs Mixxx 2.6 built with `-DQML=ON`. With our Mixxx patch, `transform="s8:N"`
on each `<screen>` encodes frames natively (C++, only changed pixel pairs);
without it Mixxx ignores the attribute and uses the QML `transformFrame`.

Run Mixxx under XWayland (`QT_QPA_PLATFORM=xcb`): on Wayland the offscreen
GL context for controller screens fails.

| File | |
|---|---|
| `Kontrol-S8-Screens.bulk.xml` | mapping: two 480x272 RGB565 (big-endian) screens |
| `KontrolS8Screen.qml` | the screen: header, status, Mixxx waveform, phrase timeline, next cue, and the S8 frame encoder (inline: Mixxx loads screen QML from its own qml dir, so relative imports don't resolve) |
| `test/s8frame.test.mjs` | `node test/s8frame.test.mjs`: tests the encoder extracted from the QML file |

| `mixxx-2.6-patches/` | Mixxx 2.6 patches on top of the [S8 HID/display patch](https://github.com/gusgustavodj/kontrol-s8-mixxx-mappings): Linux browser fix, 2.6 port, native S8 frame encoder, stem colour fallback (Traktor-made stems give every stem the same colour), shutdown crash fix (controller screens rendered after the waveform factory was destroyed), sorting from the browser tree, settable waveform frame interval (the needle ran ~70 ms early on 30 fps screens), screen PNG snapshots for debugging, initialised QML waveform gains (a screen could show a flat line) |

Install: on Mixxx `2.6`, apply the upstream S8 patch, then `git am
mixxx-2.6-patches/*.patch`, and build with `-DQML=ON -DSTEM=ON`. Copy or
symlink the `.bulk.xml` and `.qml` into `~/.mixxx/controllers` and enable the
mapping for the S8's bulk device in Preferences → Controllers.

Frame format from [kontrol-s8-protocol](https://github.com/gusgustavodj/kontrol-s8-protocol) (CC-BY-4.0).

Bars count from the first beat of the beat grid (Mixxx has no downbeat
detection); phrases default to 16 bars (controller setting `phraseBars`).

License: GPL-2.0-or-later, like Mixxx.
