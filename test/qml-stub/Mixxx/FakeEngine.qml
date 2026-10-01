pragma Singleton
import QtQuick
// Stands in for the legacy `engine` object; render-preview.sh rewrites
// `engine.` to `Mixxx.FakeEngine.` in a copy of the screen.
QtObject {
    // Scenario from the last command-line argument: 0 deck, 1 browser,
    // 2 browser + SORT BY popup, 3 deck + tempo popup, 4 stem deck, 5 BPM panel
    property int scenario: Number(Qt.application.arguments[Qt.application.arguments.length - 1]) || 0
    property int context: scenario === 1 || scenario === 2 ? 1 : 0
    property var controls: {
        var c = {bpm: 123.98, duration: 412, playposition: 0.43, track_loaded: 1, quantize: 1, beatloop_size: 8};
        if (scenario === 2) { c.left_popup_kind = 3; c.left_popup_title = 2; c.left_popup_pending_index = 2; c.left_popup_pending_descending = 1; }
        if (scenario === 3) { c.left_popup_kind = 1; c.left_popup_title = 1; c.left_popup_value = 124; c.left_popup_has_value = 1; }
        if (scenario === 4) {
            c.stem_count = 4; c.super1 = 0.5; c.loaded_chain_preset = 1; c.mute = 0;
        }
        if (scenario === 5) { c.left_active_panel = 1; c.file_bpm = 121.97; c.beats_undo_possible = 1; }
        return c;
    }
    function getSetting(name) { return undefined; }
    function getS8BrowserState(rows) {
        var t = [["Ocean Drift", "Mar de Nubes", 122.0, "8A", 418], ["Pájaro Canario", "Tenerife Deep", 121.5, "9A", 395],
                 ["Volcán", "Teide Groove Collective", 123.0, "8B", 452], ["Malpaís", "Lanzarote Minimal Unit", 124.0, "7A", 377],
                 ["Alisios (Extended Dub With A Very Long Name)", "Trade Winds", 122.5, "8A", 503], ["Calima", "Sahara Haze", 120.0, "10A", 360],
                 ["Lava Flow (Original Mix)", "Timanfaya", 124.0, "8A", 412], ["Charco Azul", "La Palma Sound System", 123.5, "9B", 431],
                 ["Barranco", "Gomera Silbo", 121.0, "6A", 388]];
        var r = t.map(function(x, i) { return {type: "track", title: x[0], artist: x[1], bpm: x[2], key: x[3], duration: x[4], stems: i % 3 === 1}; });
        return {available: true, mode: "tracks", path: "BROWSER > Crates > Lavaland 001", selectedIndex: 4,
                sortLabel: "BPM", sortDescending: false, previewPlaying: true, rows: r,
                sortCriteria: ["Title", "Artist", "BPM", "Date Added", "#", "Key"].map(function(l, i) { return {id: i, label: l}; })};
    }
}
