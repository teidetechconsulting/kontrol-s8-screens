# Kontrol S8 on Mixxx 2.6: fork status and path to upstream

Handover notes: how far our Mixxx changes deviate from upstream, what is hard to
keep merged, and what should change so the S8 support becomes a clean,
upgradable module that Mixxx could accept. Shallow overview, October 2026.

## Repositories

| What | Where |
|---|---|
| Mixxx upstream | [mixxxdj/mixxx](https://github.com/mixxxdj/mixxx), branch `2.6`, base commit `918441b` (2026-09-27, merge of #17164) |
| Original S8 work (HID/display patch, mapping, protocol) | [gusgustavodj/kontrol-s8-mixxx-mappings](https://github.com/gusgustavodj/kontrol-s8-mixxx-mappings), [gusgustavodj/kontrol-s8-protocol](https://github.com/gusgustavodj/kontrol-s8-protocol) |
| Our mapping changes (HID JS/XML) | fork [teidetechconsulting/kontrol-s8-mixxx-mappings](https://github.com/teidetechconsulting/kontrol-s8-mixxx-mappings), branch `s8-performance-basics` |
| Our QML screens + Mixxx patch series | this repo: `KontrolS8Screen.qml`, `Kontrol-S8-Screens.bulk.xml`, `mixxx-2.6-patches/` |

The Mixxx fork is not published as a git branch; it is the patch series in
`mixxx-2.6-patches/` (0002–0013), applied with `git am` on top of the original
author's patch (0001, not redistributed here because that repository has no
license). Build with `-DQML=ON -DSTEM=ON`.

Licensing caveat: the original author's repository carries no license
(GitHub: NOASSERTION). Anything derived from patch 0001 or the original
mapping needs the author's consent before it can be proposed upstream.

## Size of the deviation

Against upstream `918441b`, including the original author's patch:
**29 files, +2,671 / −23 lines.**

| File | Lines | What | Merge risk |
|---|---|---|---|
| `controllers/scripting/legacy/controllerscriptinterfacelegacy.cpp` | +1,071 | S8 functions in the generic script API (browser state/sort/preview, effect state, display state, capture) | **High**: device code in a generic API; conflicts with any API change |
| `controllers/bulk/nativenis8displaytransport.*`, `nativenis8displaycontract.h` | +758 | The original author's own display path | Medium: self-contained, but a second display system next to QML screens |
| `controllers/controllermanager.cpp` | +159 | 90 hard-coded `[S8Display]` controls; shutdown method | **High**: device state in core |
| `controllers/scripting/legacy/controllerscriptenginelegacy.cpp` | +118 | Native S8 frame encoder (`transform="s8:N"`), PNG snapshot debug aid | Medium-high |
| `effects/effectsmanager.*`, `engine/controls/loopingcontrol.cpp` | +82 | Behaviour changes from the original patch | Medium: affect all controllers |
| `qml/qmlwaveformdisplay.h`, `qml/qmlwaveformrenderer.h` | +34 | `syncInterval`, initialised members | Low |
| `engine/controls/bpmcontrol.*`, `track/steminfoimporter.cpp`, `mixxxmainwindow.cpp`, `coreservices.cpp`, mapping file handler | small | see patches below | Low |

## Patch series, classified

| Patch | Kind | Upstream? |
|---|---|---|
| 0002 explicit browser level, focus-independent enter | S8 / browser | after refactor (generic library API) |
| 0003 port to 2.6, stem-aware preview load | S8 | after refactor |
| 0004 native S8 frame encoder (`transform="s8:N"`) | S8 / screens | after refactor (generic transform registry) |
| 0005 stem colour fallback when all stems share one colour | **generic** | **yes** |
| 0006 shutdown: close controllers before `WaveformWidgetFactory` (crash) | **generic bug fix** | **yes** |
| 0007 browser sort criteria in the tree view | S8 / browser | with the library API refactor |
| 0008 QML `WaveformDisplay.syncInterval` (waveform ran ~70 ms early on 30 fps screens) | **generic** | **yes** |
| 0009 PNG snapshot of controller screens via `/tmp/s8-snapshot` | debug aid | no (or as a generic `--controller-screen-dump` option) |
| 0010 initialise QML waveform renderer factory members (NaN gains → flat waveform) | **generic bug fix** | **yes** |
| 0011 stems flag in S8 browser rows | S8 / browser | with the library API refactor |
| 0012 `beats_adjust_by` control (grid BPM by any delta) | **generic** | **yes** |
| 0013 `s8CaptureToSampler` (render a deck's loop with stem volumes into a sampler) | feature, S8-named | after refactor (generic control) |

## Problematic architecture decisions

1. **Device-specific code in generic core classes**: S8 functions in
   `ControllerScriptInterfaceLegacy`, S8 controls in `ControllerManager`, the
   S8 frame format in `ControllerScriptEngineLegacy`.
2. **Reading GUI widgets from the controller thread**: browser state comes
   from `findChild<WLibrary>` / `WLibrarySidebar` via a blocking call into the
   GUI thread. Fragile (depends on the skin; not available in the QML UI) and
   a deadlock risk at shutdown.
3. **Ad-hoc service access**: static `registerS8Services()` with weak
   pointers to `PlayerManager` / `TrackCollectionManager`.
4. **Hard-coded paths**: capture writes to
   `~/Music/Mixxx/Music/Samples/Captures`, no setting.
5. **Two mappings bridged through global controls**: the HID mapping and the
   screen (bulk) mapping exchange state via `[S8Display]`, because Mixxx has no
   notion of one device with several interfaces.
6. **Debug aid in production code** (snapshot trigger file in `/tmp`).
7. **Two display systems**: the original native transport and our QML
   screens. The QML screens do not yet cover the FX overlay and settings pages.

## What should change (in order)

1. **Send the six generic patches upstream as separate small PRs**: 0005, 0006,
   0008, 0010, 0012 (and 0007 once the browser API exists). Low effort, removes
   a third of the patch series.
2. **Browser via a generic library API**: use Mixxx's QML library models
   (`QmlLibraryProxy` / track models) or add one generic, thread-safe
   `engine.getLibrarySelection()`; drop widget scraping. Folds 0002, 0003,
   0007, 0011 into one generic change.
3. **Generic screen-transform registry**: controller screens declare an
   encoder (`transform="..."`), device encoders register as plugins; or keep
   the encoding in QML/JS and add only a generic RLE/partial-update primitive.
   Replaces 0004.
4. **Capture as a generic control**: e.g. `[ChannelN] capture_to_sampler`
   (value = sampler number) in `PlayerManager`/`SamplerBank`, target folder as
   a preference, no S8 naming. Replaces 0013; useful for every controller.
5. **Mapping-declared shared controls** instead of 90 hard-coded `[S8Display]`
   controls; longer term propose composite controllers (one device, several
   interfaces) upstream.
6. **Retire the native display transport** once the QML screens cover the FX
   overlay and settings; then the S8 support is mapping + QML + one encoder.
7. **Review the effects/looping changes** from the original patch: keep only
   what is needed, generic and opt-in.
8. **Keep the debug snapshot local** (or upstream as a generic command-line option).

## Effort (rough)

| Step | Effort |
|---|---|
| Generic PRs (1) | 1–2 days plus review time |
| Library API, transform registry, capture control, mapping controls (2–5) | 1–2 weeks |
| Retire native transport, effects/looping review (6–7) | depends on QML screen coverage; a few days |

After steps 1–5 the S8 support is a mapping, QML screens and a device encoder
on top of generic Mixxx features, and upgrades to new Mixxx versions no longer
need patch rebasing.

## Outside Mixxx (no upgrade concern)

QML screens and mapping files (installed as copies), the launcher and
real-time setup, the LateNight skin variant with deck letters, and the
PipeWire master limiter live in separate, local projects and do not touch
Mixxx's source.
