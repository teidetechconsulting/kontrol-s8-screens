import QtQuick
// Stand-in: a fake overview shape, playhead in red at 43 %
Rectangle {
    property string group; property int renderer; property int channels
    property color colorLow; property color colorMid; property color colorHigh
    color: "#14181d"
    Row {
        anchors.fill: parent
        Repeater {
            model: 120
            Item {
                width: parent.width / 120; height: parent.height
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter; width: parent.width
                    height: parent.height * (index % 40 < 6 ? 0.15 : 0.55 + 0.35 * Math.abs(Math.sin(index)))
                    color: index % 40 < 6 ? "#2f8cff" : "#ff7a3a"
                }
            }
        }
    }
    Rectangle { x: parent.width * 0.43; width: 2; height: parent.height; color: "#ff3b30" }
    Rectangle { x: parent.width * 0.62; width: 2; height: parent.height; color: "#37e05a" }
}
