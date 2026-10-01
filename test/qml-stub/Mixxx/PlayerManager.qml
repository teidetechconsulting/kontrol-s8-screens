pragma Singleton
import QtQuick
QtObject {
    property QtObject player: QtObject {
        property bool isLoaded: true; property string title: "Lava Flow (Original Mix)"
        property string artist: "Timanfaya"; property string keyText: "8A"
        property var beatsModel: null; property var hotcuesModel: null
    }
    function getPlayer(group) { return player; }
}
