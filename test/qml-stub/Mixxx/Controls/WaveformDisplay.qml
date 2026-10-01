import QtQuick
Rectangle {
    default property list<QtObject> renderers
    property string group; property real zoom; property color backgroundColor
    color: "#202830"
    Text { anchors.centerIn: parent; text: "waveform (stub)"; color: "#4a535b" }
}
