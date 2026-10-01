import QtQuick
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls

// One Kontrol S8 display. "left" shows deck 1, "right" deck 2 (deck C/D
// follow-up: take the focused deck from the HID mapping).
Mixxx.ControllerScreen {
    id: root
    required property string screenId
    readonly property int screenIndex: screenId === "right" ? 1 : 0
    // Deck focus comes from the HID mapping via [S8Display],left_deck /
    // right_deck (A/C on the left, B/D on the right).
    Mixxx.ControlProxy {
        id: focusDeck
        group: "[S8Display]"
        key: root.screenIndex === 1 ? "right_deck" : "left_deck"
    }
    readonly property int deck: focusDeck.value >= 1 && focusDeck.value <= 4
            ? Math.round(focusDeck.value) : (screenIndex === 1 ? 2 : 1)
    readonly property string deckLetter: "ABCD".charAt(deck - 1)
    property string group: "[Channel" + deck + "]"
    onGroupChanged: {
        root.player = Mixxx.PlayerManager.getPlayer(root.group);
        phrase.reloadBeats();
        phrase.refreshNextCue();
    }
    property var player: Mixxx.PlayerManager.getPlayer(root.group)
    // Stem tracks: stems as separate lanes (their colours; Mixxx falls back to
    // its default palette when a file gives every stem the same colour).
    // Other tracks: the RGB spectrum. Mixxx picks per track (the RGB renderer
    // skips waveforms with stem data, the stem renderer needs it), so both
    // stay at full gain: a gain toggled from QML did not always reach the
    // renderer and left one screen with a flat line.

    // Theme
    readonly property color bg: "#0b0d10"
    readonly property color panel: "#14181d"
    readonly property color text: "#e8ecef"
    readonly property color dim: "#8a949c"
    readonly property color faint: "#4a535b"
    readonly property color syncColor: "#3ddc84"
    readonly property color leaderColor: "#ff8a1e"
    readonly property color warn: "#ff4d4d"
    readonly property string sans: "Noto Sans"
    readonly property string mono: "Noto Sans Mono"

    init: function(controllerName, isDebug) {}
    shutdown: function() {}
    // transformFrame runs on Mixxx's controller thread, the same thread that
    // handles fader and button input. The RLE loop in s8Encode costs ms per
    // frame in QJSEngine; the raw envelope is one native copy, so input is
    // never held up behind screen encoding. Costs more USB (~261 KB/frame).
    property bool rleFrames: false
    transformFrame: function(input, timestamp) {
        return root.rleFrames ? root.s8Encode(root.screenIndex, input)
                              : root.s8EncodeRaw(root.screenIndex, input);
    }

    // S8FRAME-BEGIN — Kontrol S8 display frame: 16-byte header, run-length
    // coded RGB565 pixel pairs, 8-byte footer. Format from kontrol-s8-protocol
    // (CC-BY-4.0). Input is big-endian RGB565 (<screen endian="big">). Inline
    // because Mixxx loads screen QML from its own qml dir, so relative imports
    // do not resolve. Tested by test/s8frame.test.mjs.
    function s8Encode(screen, input) {
        var W = 480, H = 272, PAIRS = W * H / 2, MAX_RUN = 0xFFFF;
        var bytes = new Uint8Array(input);
        if (bytes.length !== W * H * 2)
            throw new Error("S8 frame: expected " + (W * H * 2) + " bytes, got " + bytes.length);
        var words = new Uint32Array(bytes.buffer, bytes.byteOffset, PAIRS);
        var out = new Uint8Array(16 + PAIRS * 6 + 8);
        out.set([0x84, 0, screen, 0x60, 0, 0, 0, 0, 0, 0, 0, 0, W >> 8, W & 0xFF, H >> 8, H & 0xFF]);
        var o = 16, i = 0;
        while (i < PAIRS) {
            var j = i + 1;
            while (j < PAIRS && words[j] === words[i] && j - i < MAX_RUN) j++;
            if (j - i >= 2) {
                var run = j - i;
                out[o++] = 0x01; out[o++] = 0; out[o++] = run >> 8; out[o++] = run & 0xFF;
                out.set(bytes.subarray(i * 4, i * 4 + 4), o); o += 4;
                i = j;
                continue;
            }
            var start = i;
            i++;
            while (i < PAIRS && i - start < MAX_RUN && !(i + 1 < PAIRS && words[i + 1] === words[i])) i++;
            var count = i - start;
            out[o++] = 0x00; out[o++] = 0; out[o++] = count >> 8; out[o++] = count & 0xFF;
            out.set(bytes.subarray(start * 4, i * 4), o); o += count * 4;
        }
        out.set([0x03, 0, 0, 0, 0x40, 0, screen, 0], o); o += 8;
        return out.buffer.slice(0, o);
    }

    // Whole frame as one literal run (65280 pairs fits the 16-bit count).
    function s8EncodeRaw(screen, input) {
        var W = 480, H = 272, PAIRS = W * H / 2;
        var bytes = new Uint8Array(input);
        if (bytes.length !== W * H * 2)
            throw new Error("S8 frame: expected " + (W * H * 2) + " bytes, got " + bytes.length);
        var out = new Uint8Array(16 + 4 + bytes.length + 8);
        out.set([0x84, 0, screen, 0x60, 0, 0, 0, 0, 0, 0, 0, 0, W >> 8, W & 0xFF, H >> 8, H & 0xFF]);
        out.set([0x00, 0, PAIRS >> 8, PAIRS & 0xFF], 16);
        out.set(bytes, 20);
        out.set([0x03, 0, 0, 0, 0x40, 0, screen, 0], 20 + bytes.length);
        return out.buffer;
    }
    // S8FRAME-END


    // ---- deck state -----------------------------------------------------
    component Co: Mixxx.ControlProxy { group: root.group }
    Co { id: loaded; key: "track_loaded"; onValueChanged: { root.player = Mixxx.PlayerManager.getPlayer(root.group); phrase.reloadBeats() } }
    Co { id: bpm; key: "bpm" }
    Co { id: rate; key: "rate" }
    Co { id: rateRange; key: "rateRange" }
    Co { id: duration; key: "duration" }
    Co { id: playpos; key: "playposition" }
    Co { id: samples; key: "track_samples" }
    Co { id: syncOn; key: "sync_enabled" }
    Co { id: leader; key: "sync_leader" }
    Co { id: keylock; key: "keylock" }
    Co { id: quantize; key: "quantize" }
    Co { id: loopOn; key: "loop_enabled" }
    Co { id: loopSize; key: "beatloop_size" }
    Co { id: playing; key: "play" }
    Co { id: stemCount; key: "stem_count" }

    // Name of a quick-effect chain preset; loaded_chain_preset indexes this list.
    function presetName(index) {
        var m = Mixxx.EffectsManager ? Mixxx.EffectsManager.quickChainPresetModel : null;
        if (!m || index < 0 || index >= m.rowCount()) return "";
        return String(m.data(m.index(Math.round(index), 0)) || "");
    }

    function clock(seconds) {
        if (!(seconds >= 0)) return "--:--";
        var s = Math.floor(seconds);
        return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2);
    }

    // ---- phrase model: bars from the beat grid, default-length phrases ----
    QtObject {
        id: phrase
        property var beats: []            // frame positions
        property int phraseBars: 16
        readonly property real frame: playpos.value * samples.value / 2
        // index of the last beat at or before the playhead, plus fraction
        readonly property real beatPos: {
            var b = beats, n = b.length, f = frame;
            if (n < 2 || f < b[0]) return 0;
            var lo = 0, hi = n - 1;
            while (lo < hi) { var mid = (lo + hi + 1) >> 1; if (b[mid] <= f) lo = mid; else hi = mid - 1; }
            var next = lo + 1 < n ? b[lo + 1] : b[lo] + (b[lo] - b[lo - 1]);
            return lo + (f - b[lo]) / (next - b[lo]);
        }
        readonly property int bar: Math.floor(beatPos / 4) + 1
        readonly property int beatInBar: Math.floor(beatPos) % 4 + 1
        readonly property int number: Math.floor((bar - 1) / phraseBars) + 1
        readonly property int barInPhrase: (bar - 1) % phraseBars + 1
        readonly property real barsLeft: phraseBars - (beatPos / 4 - (number - 1) * phraseBars)
        // next hotcue ahead of the playhead
        property var nextCue: null
        readonly property real barsToCue: nextCue ? (beatIndexOf(nextCue.pos) - beatPos) / 4 : -1

        function beatIndexOf(f) {
            var b = beats, n = b.length;
            if (n < 2) return 0;
            var lo = 0, hi = n - 1;
            while (lo < hi) { var mid = (lo + hi + 1) >> 1; if (b[mid] <= f) lo = mid; else hi = mid - 1; }
            var next = lo + 1 < n ? b[lo + 1] : b[lo] + (b[lo] - b[lo - 1]);
            return lo + (f - b[lo]) / (next - b[lo]);
        }
        function reloadBeats() {
            var m = root.player ? root.player.beatsModel : null, list = [];
            if (m) for (var i = 0; i < m.rowCount(); i++) list.push(m.data(m.index(i, 0), 257));
            beats = list;
        }
        function refreshNextCue() {
            var m = root.player ? root.player.hotcuesModel : null, best = null;
            if (m) for (var i = 0; i < m.rowCount(); i++) {
                var idx = m.index(i, 0);
                var pos = m.data(idx, 257), isLoop = m.data(idx, 260);
                if (pos > frame + 1 && !isLoop && (!best || pos < best.pos))
                    best = {pos: pos, n: m.data(idx, 261) + 1, label: m.data(idx, 259) || ""};
            }
            nextCue = best;
        }
    }
    Timer { interval: 250; running: true; repeat: true; onTriggered: phrase.refreshNextCue() }
    // A new track in the same deck, or a grid that arrives after analysis,
    // resets the beats model.
    Connections {
        target: root.player ? root.player.beatsModel : null
        function onModelReset() { phrase.reloadBeats(); }
    }

    // ---- browser: the HID mapping sets [S8Display] context 1 while BROWSE is active
    Mixxx.ControlProxy {
        id: context
        group: "[S8Display]"
        key: root.screenIndex === 1 ? "right_context" : "left_context"
    }
    readonly property bool browsing: Math.round(context.value) === 1
    readonly property bool browserApi: typeof engine !== "undefined" && typeof engine.getS8BrowserState === "function"
    property var browser: ({})
    Timer {
        // getS8BrowserState blocks the controller thread until the GUI thread
        // answers, so poll only while the browser is open.
        interval: 100; repeat: true; triggeredOnStart: true
        running: root.browsing && root.browserApi
        onTriggered: root.browser = engine.getS8BrowserState(9) || ({})
    }

    // ---- popups published by the HID mapping (kind 0 = none, 2 = warning;
    // title 1 BPM, 2 SORT BY, 3 LOOP SIZE, 4 DECK LOCKED, 5 LOADING)
    component Popup: Mixxx.ControlProxy { group: "[S8Display]" }
    readonly property string sidePrefix: root.screenIndex === 1 ? "right_" : "left_"
    Popup { id: popupKind; key: root.sidePrefix + "popup_kind" }
    Popup { id: popupTitle; key: root.sidePrefix + "popup_title" }
    Popup { id: popupValue; key: root.sidePrefix + "popup_value" }
    Popup { id: popupHasValue; key: root.sidePrefix + "popup_has_value" }
    Popup { id: popupIndex; key: root.sidePrefix + "popup_pending_index" }
    Popup { id: popupDescending; key: root.sidePrefix + "popup_pending_descending" }

    Component.onCompleted: {
        console.log("S8 screen " + root.screenId + ": browser API " + (root.browserApi ? "available" : "missing"));
        var setting = typeof engine !== "undefined" && engine.getSetting ? engine.getSetting("phraseBars") : undefined;
        phrase.phraseBars = Number(setting) || 16;
        phrase.reloadBeats();
    }

    // ---- layout (480x272) -------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: root.bg

        // Header
        Item {
            id: header
            x: 6; y: 3; width: parent.width - 12; height: 42
            Rectangle {
                id: badge; width: 22; height: parent.height - 6; radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.deck <= 2 ? "#2f8cff" : "#e8ecef"   // A/B blue, C/D white (Traktor)
                Text { anchors.centerIn: parent; text: root.deckLetter; color: root.bg; font.family: root.sans; font.pixelSize: 17; font.bold: true }
            }
            Column {
                anchors.left: badge.right; anchors.leftMargin: 6; anchors.right: stats.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                Text { width: parent.width; elide: Text.ElideRight; text: root.player && root.player.isLoaded ? root.player.title : "No track"; color: root.text; font.family: root.sans; font.pixelSize: 15; font.bold: true }
                Text { width: parent.width; elide: Text.ElideRight; text: root.player && root.player.isLoaded ? root.player.artist : ""; color: root.dim; font.family: root.sans; font.pixelSize: 12 }
            }
            Row {
                id: stats; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.right: parent.right; text: bpm.value > 0 ? bpm.value.toFixed(2) : "--"; color: root.text; font.family: root.mono; font.pixelSize: 21; font.bold: true }
                    Text {
                        anchors.right: parent.right
                        property real pct: rate.value * rateRange.value * 100
                        text: (pct >= 0 ? "+" : "") + pct.toFixed(1) + "%"; color: root.dim; font.family: root.mono; font.pixelSize: 10
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter; width: 40; height: 26; radius: 3
                    color: "#2a3139"
                    Text { anchors.centerIn: parent; text: root.player ? root.player.keyText : ""; color: root.text; font.family: root.mono; font.pixelSize: 14; font.bold: true }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "-" + root.clock(duration.value * (1 - playpos.value))
                    color: duration.value * (1 - playpos.value) < 30 && playing.value > 0 ? root.warn : root.text
                    font.family: root.mono; font.pixelSize: 21; font.bold: true
                }
            }
        }

        // Status chips
        Row {
            id: status
            x: 6; anchors.top: header.bottom; anchors.topMargin: 2; spacing: 4; height: 16
            component Chip: Rectangle {
                property string label; property color tint; property bool on
                height: 16; width: t.implicitWidth + 10; radius: 2
                color: on ? tint : "transparent"; border.width: on ? 0 : 1; border.color: root.faint
                Text { id: t; anchors.centerIn: parent; text: parent.label; color: parent.on ? root.bg : root.faint; font.family: root.sans; font.pixelSize: 10; font.bold: true }
            }
            Chip { label: leader.value > 0 ? "MASTER" : "SYNC"; tint: leader.value > 0 ? root.leaderColor : root.syncColor; on: syncOn.value > 0 }
            Chip { label: "KEY LOCK"; tint: root.dim; on: keylock.value > 0 }
            Chip { label: "Q"; tint: root.dim; on: quantize.value > 0 }
            Chip { label: "LOOP " + loopSize.value; tint: root.syncColor; on: loopOn.value > 0 }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: status.verticalCenter
            text: "BAR " + phrase.bar + "." + phrase.beatInBar + "  ·  " + root.clock(duration.value * playpos.value) + " / " + root.clock(duration.value)
            color: root.dim; font.family: root.mono; font.pixelSize: 11
        }

        // Waveform: Mixxx's own renderers (RGB bands, stems, beat grid, hotcues, loop)
        MixxxControls.WaveformDisplay {
            id: wave
            group: root.group
            anchors.top: status.bottom; anchors.topMargin: 4
            width: parent.width; height: 110
            zoom: 3
            backgroundColor: root.bg
            // The play position is predicted one frame ahead; Mixxx assumes
            // 100 ms unless told the real interval (33 ms at 30 fps). Older
            // builds lack the property.
            Component.onCompleted: if ("syncInterval" in wave) wave.syncInterval = 33
            Mixxx.WaveformRendererMarkRange {
                Mixxx.WaveformMarkRange {
                    startControl: "loop_start_position"; endControl: "loop_end_position"; enabledControl: "loop_enabled"
                    color: "#3ddc84"; opacity: 0.25; disabledColor: "#ffffff"; disabledOpacity: 0.08
                }
            }
            // The RGB renderer mixes the bands into one colour per column, so the
            // band colours must be far apart: bass red-orange, mids green,
            // highs blue (kick = warm, vocals/synths = green, hats = blue).
            Mixxx.WaveformRendererRGB {
                axesColor: "#00ffffff"; lowColor: "#ff3a1e"; midColor: "#37e05a"; highColor: "#2f8cff"
                gainAll: 1.0; gainLow: 1.0; gainMid: 1.0; gainHigh: 1.0
            }
            Mixxx.WaveformRendererStem { gainAll: 1.0; splitStemTracks: true }
            Mixxx.WaveformRendererBeat { color: "#40ffffff" }
            Mixxx.WaveformRendererMark {
                playMarkerColor: "#ff3b30"; playMarkerBackground: "transparent"
                defaultMark: Mixxx.WaveformMark { align: "top|left"; color: "#ff8a1e"; textColor: "#0b0d10"; text: " %1 " }
                untilMark.showTime: false; untilMark.showBeats: false
            }
        }

        // Phrase timeline: current phrase + countdown, next cue in bars
        Item {
            id: phraseRow
            x: 6; width: parent.width - 12
            anchors.top: wave.bottom; anchors.topMargin: 6; height: 44
            Text {
                y: 0; text: "PHRASE " + phrase.number + "  ·  " + phrase.barInPhrase + "/" + phrase.phraseBars
                color: root.dim; font.family: root.mono; font.pixelSize: 12; font.bold: true
            }
            Row {
                anchors.right: parent.right; y: -3; spacing: 5
                Text { id: barsLeftText; text: phrase.barsLeft.toFixed(1); color: phrase.barsLeft < 2 ? root.warn : root.text; font.family: root.mono; font.pixelSize: 18; font.bold: true }
                Text { anchors.baseline: barsLeftText.baseline; text: "BARS  →  NEXT PHRASE"; color: root.dim; font.family: root.mono; font.pixelSize: 11; font.bold: true }
            }
            Row {   // bars of the current phrase, played ones filled, beat ticks in the current bar
                id: blocks
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 18; spacing: 2
                Repeater {
                    model: phrase.phraseBars
                    Rectangle {
                        property int n: index + 1
                        width: (blocks.width - (phrase.phraseBars - 1) * 2) / phrase.phraseBars; height: blocks.height; radius: 1
                        color: n < phrase.barInPhrase ? "#2f6fff" : (n === phrase.barInPhrase ? "#1a2a44" : "#1a1f25")
                        Row {
                            visible: n === phrase.barInPhrase
                            anchors.fill: parent; anchors.margins: 2; spacing: 1
                            Repeater { model: 4; Rectangle { width: (parent.width - 3) / 4; height: parent.height; color: index < phrase.beatInBar ? "#5fd4df" : "transparent" } }
                        }
                    }
                }
            }
        }

        // Next hotcue; on stem tracks compact, above the stem effect cells
        Rectangle {
            id: bottomPanel
            readonly property bool stems: stemCount.value > 0
            anchors.top: phraseRow.bottom; anchors.topMargin: 6
            anchors.bottom: parent.bottom; anchors.bottomMargin: 4
            x: 6; width: parent.width - 12; radius: 3; color: root.panel
            Item {
                id: cueLine
                width: parent.width; height: bottomPanel.stems ? 16 : parent.height
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    text: phrase.nextCue ? "NEXT CUE " + phrase.nextCue.n + (phrase.nextCue.label ? "  " + phrase.nextCue.label : "") : "NO CUE AHEAD"
                    color: phrase.nextCue ? root.leaderColor : root.faint; font.family: root.sans
                    font.pixelSize: bottomPanel.stems ? 10 : 13; font.bold: true
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    visible: phrase.nextCue !== null
                    text: phrase.barsToCue.toFixed(1) + " BARS"
                    color: root.text; font.family: root.mono; font.pixelSize: bottomPanel.stems ? 11 : 16; font.bold: true
                }
            }
            // Per stem: colour, name, quick effect and knob position. Knob turns
            // the effect, SHIFT+knob and the display arrows change it.
            Row {
                visible: bottomPanel.stems
                anchors.top: cueLine.bottom; anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: parent.bottom; anchors.margins: 2; spacing: 2
                Repeater {
                    model: bottomPanel.stems && root.player ? root.player.stemsModel : 0
                    Item {   // an Item: the model's "color" role would override a Rectangle's colour
                        id: stemCell
                        required property int index
                        required property string label
                        required property color color
                        readonly property string fxGroup: "[QuickEffectRack1_" + root.group.slice(0, -1) + "_Stem" + (index + 1) + "]]"
                        Mixxx.ControlProxy { id: stemSuper; group: stemCell.fxGroup; key: "super1" }
                        Mixxx.ControlProxy { id: stemPreset; group: stemCell.fxGroup; key: "loaded_chain_preset" }
                        Mixxx.ControlProxy { id: stemMute; group: root.group.slice(0, -1) + "_Stem" + (stemCell.index + 1) + "]"; key: "mute" }
                        width: (parent.width - 6) / 4; height: parent.height
                        opacity: stemMute.value > 0 ? 0.35 : 1
                        Rectangle { anchors.fill: parent; radius: 2; color: "#0f1216" }
                        Rectangle { width: 3; height: parent.height; radius: 1; color: stemCell.color }
                        Text {
                            id: stemText
                            x: 7; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.64 - 7
                            elide: Text.ElideRight
                            text: stemCell.label.toUpperCase() + " " + root.presetName(stemPreset.value)
                            color: root.text; font.family: root.sans; font.pixelSize: 9; font.bold: true
                        }
                        Rectangle {   // knob position
                            anchors.left: stemText.right; anchors.leftMargin: 3; anchors.right: parent.right
                            anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                            height: 4; radius: 1; color: "#2a3139"
                            Rectangle { width: 3; height: parent.height; color: stemCell.color; x: stemSuper.value * (parent.width - 3) }
                        }
                    }
                }
            }
        }

        // Browser: replaces the deck view while BROWSE is active
        Rectangle {
            id: browserView
            anchors.fill: parent
            visible: root.browsing
            color: root.bg
            readonly property var rows: root.browser.rows || []
            readonly property int selected: root.browser.selectedIndex || 0
            readonly property bool tree: root.browser.mode === "tree"

            Rectangle {
                id: browserHeader
                width: parent.width; height: 26; color: root.panel
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 8; anchors.right: sortText.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideLeft
                    text: root.browser.path || "BROWSER"
                    color: root.text; font.family: root.sans; font.pixelSize: 12; font.bold: true
                }
                Text {
                    id: sortText
                    anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    text: (root.browser.previewPlaying ? "▶ PREVIEW   " : "")
                          + (!browserView.tree && root.browser.sortLabel
                             ? root.browser.sortLabel.toUpperCase() + (root.browser.sortDescending ? " ▼" : " ▲") : "")
                    color: root.browser.previewPlaying ? root.syncColor : root.dim
                    font.family: root.mono; font.pixelSize: 11; font.bold: true
                }
            }

            Column {
                anchors.top: browserHeader.bottom; anchors.topMargin: 2
                width: parent.width
                Repeater {
                    model: browserView.rows.length
                    Rectangle {
                        readonly property var row: browserView.rows[index] || ({})
                        readonly property bool isSelected: index === browserView.selected
                        width: parent.width; height: 27
                        color: isSelected ? "#1a2a44" : (index % 2 ? "#0f1216" : "transparent")
                        Rectangle { width: 3; height: parent.height; color: "#2f8cff"; visible: parent.isSelected }
                        Row {
                            id: names
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - (browserView.tree ? 10 : meta.width + 16)
                            spacing: 8
                            Text {
                                id: title
                                width: Math.min(implicitWidth, names.width * (row.artist ? 0.62 : 1))
                                elide: Text.ElideRight
                                text: (row.type === "folder" ? (row.expandable ? "▸ " : "  ") : "") + (row.title || "")
                                color: root.text; font.family: root.sans; font.pixelSize: 14; font.bold: parent.parent.isSelected
                            }
                            Text {
                                width: names.width - title.width - names.spacing
                                elide: Text.ElideRight
                                text: row.artist || ""
                                color: root.dim; font.family: root.sans; font.pixelSize: 13
                            }
                        }
                        Row {
                            id: meta
                            visible: !browserView.tree
                            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Text { width: 46; horizontalAlignment: Text.AlignRight; text: row.bpm > 0 ? row.bpm.toFixed(1) : ""; color: root.text; font.family: root.mono; font.pixelSize: 13 }
                            Text { width: 30; horizontalAlignment: Text.AlignHCenter; text: row.key || ""; color: root.text; font.family: root.mono; font.pixelSize: 13; font.bold: true }
                            Text { width: 36; horizontalAlignment: Text.AlignRight; text: row.duration > 0 ? root.clock(row.duration) : ""; color: root.dim; font.family: root.mono; font.pixelSize: 13 }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.browserApi || (root.browser.available === false)
                text: root.browserApi ? "Library not available" : "Browser needs the S8 Mixxx patch"
                color: root.faint; font.family: root.sans; font.pixelSize: 14
            }
        }

        // Popup over either view
        Rectangle {
            id: popup
            readonly property int title: Math.round(popupTitle.value)
            readonly property bool sort: title === 2
            readonly property var criteria: root.browser.sortCriteria || []
            visible: popupKind.value > 0 && title > 0
            anchors.centerIn: parent
            width: sort ? 260 : 220
            height: sort ? 40 + criteria.length * 24 : 84
            radius: 4; color: root.panel
            border.width: 2; border.color: popupKind.value === 2 ? root.warn : "#2f8cff"
            Text {
                id: popupHeading
                x: 12; y: 8
                text: ["", "TEMPO", "SORT BY", "LOOP SIZE", "DECK LOCKED", "LOADING"][popup.title] || ""
                color: root.dim; font.family: root.sans; font.pixelSize: 12; font.bold: true
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 12; y: 8
                visible: popup.sort
                text: popupDescending.value > 0 ? "DESCENDING ▼" : "ASCENDING ▲"
                color: root.dim; font.family: root.mono; font.pixelSize: 11; font.bold: true
            }
            Text {
                visible: !popup.sort && popupHasValue.value > 0
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                text: popup.title === 1 ? popupValue.value.toFixed(2) : String(popupValue.value)
                color: root.text; font.family: root.mono; font.pixelSize: 30; font.bold: true
            }
            Column {
                visible: popup.sort
                anchors.top: popupHeading.bottom; anchors.topMargin: 8
                x: 6; width: parent.width - 12
                Repeater {
                    model: popup.criteria.length
                    Rectangle {
                        readonly property bool pending: index === Math.round(popupIndex.value)
                        width: parent.width; height: 24; radius: 2
                        color: pending ? "#1a2a44" : "transparent"
                        Rectangle { width: 3; height: parent.height; color: "#2f8cff"; visible: parent.pending }
                        Text {
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            text: String(popup.criteria[index].label || "").toUpperCase()
                            color: parent.pending ? root.text : root.dim
                            font.family: root.sans; font.pixelSize: 14; font.bold: parent.pending
                        }
                    }
                }
            }
        }
    }
}
