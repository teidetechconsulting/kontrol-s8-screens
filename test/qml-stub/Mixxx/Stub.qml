import QtQuick
QtObject {
    default property list<QtObject> data
    property string startControl; property string endControl; property string enabledControl
    property string align; property string text
    property color color; property color disabledColor; property color textColor
    property color lowColor; property color midColor; property color highColor; property color axesColor
    property color playMarkerColor; property color playMarkerBackground
    property real opacity; property real disabledOpacity
    property real gainAll; property real gainLow; property real gainMid; property real gainHigh
    property bool splitStemTracks
    property QtObject defaultMark
    property UntilMark untilMark: UntilMark {}
}
