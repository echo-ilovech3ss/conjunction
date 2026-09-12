pragma Singleton
import QtQuick

QtObject {
    id: root

    // Indicates whether the user is actively using the keyboard for focus navigation
    property bool keyboardNavigationActive: true

    function setKeyboardActive(active) {
        keyboardNavigationActive = active;
    }
}
