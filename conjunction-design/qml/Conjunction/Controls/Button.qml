import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.Button {
    id: control

    property string sizeClass: "regular" // "compact", "regular", "large"
    property bool isDefault: false
    property bool isSecondary: false
    property bool isDestructive: false
    property string iconName: ""
    property Action conjunctionAction: null

    onConjunctionActionChanged: {
        if (conjunctionAction) {
            text = Qt.binding(function() { return conjunctionAction.text; });
            iconName = Qt.binding(function() { return conjunctionAction.iconName; });
            enabled = Qt.binding(function() { return conjunctionAction.enabled; });
            isDefault = (conjunctionAction.role === "default");
            isDestructive = (conjunctionAction.role === "destructive");
        }
    }
    onClicked: {
        if (conjunctionAction) conjunctionAction.trigger();
    }

    implicitWidth: Math.max(Geometry.minTargetSize, contentLayout.implicitWidth + (sizeClass === "compact" ? Spacing.sm * 2 : Spacing.md * 2))
    implicitHeight: {
        if (sizeClass === "compact") return Geometry.controlHeightSmall;
        if (sizeClass === "large") return Geometry.controlHeightLarge;
        return Geometry.controlHeightMedium;
    }

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Button
    Accessible.name: text || iconName
    Accessible.focusable: true

    background: Rectangle {
        id: bg
        radius: (control.sizeClass === "large") ? Geometry.radiusMedium : Geometry.radiusSmall
        border.width: Geometry.separatorThickness

        color: {
            if (!control.enabled) return Theme.surfaceSecondary;
            if (control.isDestructive) {
                if (control.down) return Theme.destructiveHover;
                if (control.hovered) return Theme.destructiveHover;
                return Theme.destructive;
            }
            if (control.isDefault) {
                if (control.down) return Theme.accentPressed;
                if (control.hovered) return Theme.accentHover;
                return Theme.accent;
            }
            if (control.down) return Theme.surfaceSecondary;
            if (control.hovered) return Theme.surfaceSecondary;
            return control.isSecondary ? Theme.surfaceSecondary : Theme.surface;
        }

        border.color: {
            if (!control.enabled) return Theme.separator;
            if (control.isDefault || control.isDestructive) return "transparent";
            if (control.hovered) return Theme.accent;
            return Theme.separator;
        }

        Behavior on color {
            ColorAnimation { duration: Motion.duration(Motion.fast); easing.type: Motion.easingStandard }
        }
        Behavior on border.color {
            ColorAnimation { duration: Motion.duration(Motion.fast); easing.type: Motion.easingStandard }
        }

        FocusRing {
            active: control.activeFocus && FocusModel.keyboardNavigationActive
            target: bg
        }
    }

    contentItem: RowLayout {
        id: contentLayout
        spacing: Spacing.xs
        anchors.centerIn: parent

        Icon {
            id: btnIcon
            visible: control.iconName !== "" || (control.icon && control.icon.name !== "")
            name: control.iconName !== "" ? control.iconName : (control.icon ? control.icon.name : "")
            size: (control.sizeClass === "compact") ? 14 : 16
            color: {
                if (!control.enabled) return Theme.textDisabled;
                if (control.isDefault || control.isDestructive) return "#FFFFFF";
                return Theme.textPrimary;
            }
        }

        Text {
            id: btnText
            visible: control.text !== ""
            text: control.text
            font: (control.sizeClass === "compact") ? Typography.caption : ((control.sizeClass === "large") ? Typography.sectionHeading : Typography.controlLabel)
            color: {
                if (!control.enabled) return Theme.textDisabled;
                if (control.isDefault || control.isDestructive) return "#FFFFFF";
                return Theme.textPrimary;
            }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    Keys.onReturnPressed: function(event) {
        if (control.enabled) {
            control.clicked();
            event.accepted = true;
        }
    }
}
