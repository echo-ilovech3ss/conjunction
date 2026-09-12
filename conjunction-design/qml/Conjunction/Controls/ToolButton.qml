import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.ToolButton {
    id: control

    property string iconName: ""
    property string tooltipText: ""
    property Action conjunctionAction: null

    onConjunctionActionChanged: {
        if (conjunctionAction) {
            text = Qt.binding(function() { return conjunctionAction.text; });
            iconName = Qt.binding(function() { return conjunctionAction.iconName; });
            enabled = Qt.binding(function() { return conjunctionAction.enabled; });
            tooltipText = Qt.binding(function() { return conjunctionAction.text; });
        }
    }
    onClicked: {
        if (conjunctionAction) conjunctionAction.trigger();
    }

    implicitWidth: Math.max(Geometry.minTargetSize, contentLayout.implicitWidth + Spacing.sm * 2)
    implicitHeight: Geometry.controlHeightMedium

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Button
    Accessible.name: text || tooltipText || iconName
    Accessible.focusable: true

    background: Rectangle {
        id: bg
        radius: Geometry.radiusSmall
        border.width: Geometry.separatorThickness

        color: {
            if (!control.enabled) return "transparent";
            if (control.down || control.checked) return Theme.selection;
            if (control.hovered) return Theme.surfaceSecondary;
            return "transparent";
        }

        border.color: {
            if (control.down || control.checked) return Theme.separator;
            if (control.hovered) return Theme.separator;
            return "transparent";
        }

        Behavior on color {
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
            visible: control.iconName !== "" || (control.icon && control.icon.name !== "")
            name: control.iconName !== "" ? control.iconName : (control.icon ? control.icon.name : "")
            size: 16
            color: {
                if (!control.enabled) return Theme.textDisabled;
                if (control.checked) return Theme.accent;
                return Theme.textPrimary;
            }
        }

        Text {
            visible: control.text !== ""
            text: control.text
            font: Typography.controlLabel
            color: {
                if (!control.enabled) return Theme.textDisabled;
                if (control.checked) return Theme.accent;
                return Theme.textPrimary;
            }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    ToolTip {
        visible: control.hovered && (control.tooltipText !== "" || (control.text === "" && control.iconName !== ""))
        text: control.tooltipText !== "" ? control.tooltipText : control.iconName
        delay: 500
    }
}
