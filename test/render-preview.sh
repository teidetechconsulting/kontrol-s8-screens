#!/usr/bin/env bash
# Render KontrolS8Screen.qml offline with stub Mixxx modules.
# Usage: test/render-preview.sh <scenario: 0 deck, 1 browser, 2 sort popup, 3 tempo popup, 4 stem deck, 5 BPM panel> <out.png>
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
sed -e 's/typeof engine !== "undefined"/true/g' -e 's/\bengine\./Mixxx.FakeEngine./g' \
    "$here/../KontrolS8Screen.qml" > "$tmp/TestScreen.qml"
cat > "$tmp/harness.qml" <<QML
import QtQuick
Item {
    width: 480; height: 272
    TestScreen { id: screen; screenId: "left" }
    Timer { interval: 400; running: true
        onTriggered: screen.grabToImage(function(r) { r.saveToFile("$(realpath -m "$2")"); Qt.quit(); }) }
}
QML
env -i HOME="$HOME" PATH=/usr/bin:/bin LANG=C.UTF-8 QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES="qml.debug=true" QML_IMPORT_PATH="$here/qml-stub" QT_QUICK_BACKEND=software \
    /usr/lib64/qt6/bin/qml -platform offscreen "$tmp/harness.qml" -- "$1"
