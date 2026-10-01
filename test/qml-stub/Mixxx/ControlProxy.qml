import QtQuick
import Mixxx 1.0 as Mixxx
QtObject {
    property string group; property string key
    property real value: key.endsWith("_context") ? Mixxx.FakeEngine.context
        : key.endsWith("_deck") ? 1 : (Mixxx.FakeEngine.controls[key] || 0)
}
