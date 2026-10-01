pragma Singleton
import QtQuick
QtObject {
    property QtObject player: QtObject {
        property bool isLoaded: true; property string title: "Lava Flow (Original Mix)"
        property string artist: "Timanfaya"; property string keyText: "8A"
        property var beatsModel: null; property var hotcuesModel: null
        property ListModel stemsModel: ListModel {
            ListElement { label: "Drums"; color: "#009E73" } ListElement { label: "Bass"; color: "#D55E00" }
            ListElement { label: "Other"; color: "#CC79A7" } ListElement { label: "Vocals"; color: "#56B4E9" }
        }
    }
    function getPlayer(group) { return player; }
}
