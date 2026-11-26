import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.Button {
    id: control

    // SPEC §2.3 sizeClass: "mini" (16), "small"/"compact" (27), "regular" (32), "large"/"extraLarge" (40), "pill" (28), "toolbar" (36)
    property string sizeClass: "regular"
    property bool capsule: true
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
    onPressed: FocusModel.markPointerNavigation()
    onClicked: {
        if (conjunctionAction) conjunctionAction.trigger();
    }

    readonly property int targetHeight: {
        if (sizeClass === "pill") return Geometry.alertPillHeight;
        if (sizeClass === "toolbar") return Geometry.toolbarButtonSize;
        return Geometry.pushButtonHeight(sizeClass);
    }

    implicitWidth: (sizeClass === "toolbar" && text === "")
        ? targetHeight
        : Math.max(sizeClass === "mini" ? 44 : 64, contentLayout.implicitWidth + (sizeClass === "mini" ? Spacing.sm : (sizeClass === "small" || sizeClass === "compact" ? Spacing.md * 1.5 : Spacing.lg * 1.5)))
    implicitHeight: targetHeight

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Button
    Accessible.name: text || iconName
    Accessible.focusable: true

    readonly property real resolvedRadius: {
        if (sizeClass === "toolbar" || sizeClass === "pill" || capsule) {
            return height * 0.5;
        }
        return (sizeClass === "large" || sizeClass === "extraLarge") ? 10 : Geometry.radiusSmall;
    }

    background: Item {
        id: bgWrapper

        readonly property real radius: control.resolvedRadius

        // Ambient separation on glass pill buttons (SPEC §2.5)
        Rectangle {
            visible: control.enabled && (control.sizeClass === "toolbar" || control.sizeClass === "pill")
            anchors.fill: parent
            anchors.topMargin: 2
            radius: bgWrapper.radius
            color: Qt.rgba(0, 0, 0, Theme.isDark ? 0.24 : 0.08)
            z: -1
        }

        SquircleRect {
            id: bg
            anchors.fill: parent
            radius: bgWrapper.radius
            color: {
                if (!control.enabled) return Theme.controlFill;
                if (control.isDestructive) {
                    if (control.down) return Qt.darker(Theme.destructive, 1.15);
                    if (control.hovered) return Theme.destructiveHover;
                    return Theme.destructive;
                }
                if (control.isDefault) {
                    if (control.down) return Theme.accentPressed;
                    if (control.hovered) return Theme.accentHover;
                    return Theme.accent;
                }
                if (control.down) return Theme.controlFillPressed;
                if (control.hovered) return Theme.controlFillHover;
                return control.isSecondary ? Theme.controlFill : Theme.surface;
            }
            borderColor: {
                if (Appearance.shouldIncreaseContrast) return Theme.highContrastBorderColor;
                if (!control.enabled) return Theme.separator;
                if (control.isDefault || control.isDestructive) return "transparent";
                return Theme.separator;
            }
            borderWidth: (control.isDefault || control.isDestructive) && !Appearance.shouldIncreaseContrast ? 0 : Geometry.separatorThickness
        }

        scale: (control.down && !Appearance.reducedMotion) ? 0.985 : 1.0
        Behavior on scale {
            NumberAnimation { duration: Motion.hoverSwap }
        }

        FocusRing {
            target: bgWrapper
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
                id: btnIcon
                visible: control.iconName !== "" || (control.icon && control.icon.name !== "")
                name: control.iconName !== "" ? control.iconName : (control.icon ? control.icon.name : "")
                size: (control.sizeClass === "mini") ? 12 : ((control.sizeClass === "small" || control.sizeClass === "compact") ? 14 : 16)
                Layout.preferredWidth: size
                Layout.preferredHeight: size
                color: {
                    if (!control.enabled) return Theme.textDisabled;
                    if (control.isDefault || control.isDestructive) return "#FFFFFF";
                    return Theme.textPrimary;
                }
            }

            Text {
                id: btnText
                visible: control.text !== ""
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: control.text
                font: {
                    if (control.sizeClass === "mini") return Typography.miniControl;
                    if (control.sizeClass === "small" || control.sizeClass === "compact") return Typography.subheadline;
                    if (control.sizeClass === "large" || control.sizeClass === "extraLarge") return Typography.title3;
                    return Typography.body;
                }
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
    }

    ToolTip {
        visible: control.hovered && btnText.truncated && control.text !== ""
        text: control.text
        delay: 400
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            FocusModel.markKeyboardNavigation();
        }
    }

    Keys.onReturnPressed: function(event) {
        if (control.enabled) {
            FocusModel.markKeyboardNavigation();
            control.clicked();
            event.accepted = true;
        }
    }
    Keys.onSpacePressed: function(event) {
        if (control.enabled) {
            FocusModel.markKeyboardNavigation();
            control.clicked();
            event.accepted = true;
        }
    }
}
