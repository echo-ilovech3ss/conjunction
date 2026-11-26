pragma Singleton
import QtQuick

QtObject {
    id: root

    // Tracks keyboard vs pointer focus origin (SPEC §2.7 Trigger Policy)
    property bool keyboardNavigationActive: false

    function setKeyboardActive(active) {
        keyboardNavigationActive = !!active;
    }

    function markKeyboardNavigation() {
        keyboardNavigationActive = true;
    }

    function markPointerNavigation() {
        keyboardNavigationActive = false;
    }

    // Buttons/checkboxes/radios only show focus halo on keyboard navigation; text inputs show halo on any focus
    function shouldShowRing(targetItem, isTextInput) {
        if (!targetItem || !targetItem.activeFocus) return false;
        if (isTextInput) return true;
        if (keyboardNavigationActive) return true;
        var reason = targetItem.focusReason;
        return reason === Qt.TabFocusReason
            || reason === Qt.BacktabFocusReason
            || reason === Qt.ShortcutFocusReason
            || reason === Qt.OtherFocusReason;
    }
}
