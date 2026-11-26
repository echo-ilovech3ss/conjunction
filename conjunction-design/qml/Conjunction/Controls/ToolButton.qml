import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.ToolButton {
    id: control

    // SPEC §2.3 Toolbar Icon Circle / Pill: regular 36 pt (cr=18), small 28 pt (cr=14)
    property string sizeClass: "regular"
    property string iconName: ""
    property string tooltipText: ""
    property Action conjunctionAction: null
    property bool pillGlass: true

    readonly property int btnH: (sizeClass === "small" || sizeClass === "compact")
        ? Geometry.toolbarButtonSmallSize
        : Geometry.toolbarButtonSize

    onConjunctionActionChanged: {
        if (conjunctionAction) {
            text = Qt.binding(function() { return conjunctionAction.text; });
            iconName = Qt.binding(function() { return conjunctionAction.iconName; });
            enabled = Qt.binding(function() { return conjunctionAction.enabled; });
            tooltipText = Qt.binding(function() { return conjunctionAction.text; });
        }
    }
    onPressed: FocusModel.markPointerNavigation()
    onClicked: {
        if (conjunctionAction) conjunctionAction.trigger();
    }

    implicitWidth: (text === "" && !pillGlass) ? btnH : Math.max(btnH, contentLayout.implicitWidth + Spacing.md)
    implicitHeight: btnH

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Button
    Accessible.name: text || tooltipText || iconName
    Accessible.focusable: true

    background: Rectangle {
        id: bg
        radius: height * 0.5
        border.width: Appearance.shouldIncreaseContrast ? 1.0 : Geometry.hairlineThickness

        color: {
            if (!control.enabled) return "transparent";
            if (control.down || control.checked) return Theme.isDark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12);
            if (control.hovered) return Theme.controlFillHover;
            return control.pillGlass ? Theme.controlFill : "transparent";
        }

        border.color: {
            if (Appearance.shouldIncreaseContrast) return Theme.highContrastBorderColor;
            if (control.hovered || control.checked || control.pillGlass) return Theme.separator;
            return "transparent";
        }

        Behavior on color {
            ColorAnimation { duration: Motion.hoverSwap }
        }

        FocusRing {
            target: bg
            isTextInput: false
        }
    }

    contentItem: Item {
        implicitWidth: contentLayout.implicitWidth
        implicitHeight: contentLayout.implicitHeight

        RowLayout {
            id: contentLayout
            spacing: Spacing.xs
            x: Math.max(0, Math.round((parent.width - width) * 0.5))
            width: Math.min(implicitWidth, Math.max(0, parent.width))
            height: parent.height

            Icon {
                visible: control.iconName !== "" || (control.icon && control.icon.name !== "")
                name: control.iconName !== "" ? control.iconName : (control.icon ? control.icon.name : "")
                size: (control.sizeClass === "small" || control.sizeClass === "compact") ? 15 : 17
                Layout.preferredWidth: size
                Layout.preferredHeight: size
                opsz: 24
                fill: control.checked ? 1 : 0
                color: {
                    if (!control.enabled) return Theme.textDisabled;
                    if (control.checked) return Theme.accent;
                    return Theme.textPrimary;
                }
            }

            Text {
                id: toolBtnText
                visible: control.text !== ""
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: control.text
                font: Typography.body
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
    }

    ToolTip {
        visible: control.hovered && (toolBtnText.truncated || control.tooltipText !== "" || (control.text === "" && control.iconName !== ""))
        text: toolBtnText.truncated ? control.text : (control.tooltipText !== "" ? control.tooltipText : control.iconName)
        delay: 500
    }
}
