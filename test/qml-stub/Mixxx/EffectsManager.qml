pragma Singleton
import QtQuick
QtObject {
    property QtObject quickChainPresetModel: QtObject {
        readonly property var names: ["Echo", "Filter", "Moog Filter", "Reverb"]
        function rowCount() { return names.length; }
        function index(row, col) { return row; }
        function data(idx) { return names[idx]; }
    }
    property ListModel unused: ListModel {
        ListElement { display: "Echo" } ListElement { display: "Filter" } ListElement { display: "Moog Filter" } ListElement { display: "Reverb" }
    }
}
