import QtQuick

QtObject {
    id: root

    property string text: ""
    property string iconName: ""
    property string shortcut: ""
    property bool enabled: true
    property bool checkable: false
    property bool checked: false
    property string role: "normal" // "normal", "default", "cancel", "destructive"

    signal triggered()

    function trigger() {
        if (enabled) {
            if (checkable) {
                checked = !checked;
            }
            triggered();
        }
    }
}
