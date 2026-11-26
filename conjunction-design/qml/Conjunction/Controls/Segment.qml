import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: segment

    readonly property bool isSegment: true
    property string text: ""
    property string iconName: ""
    property bool selected: false

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumWidth: iconName !== "" && text !== "" ? 32 : 24
    implicitWidth: segRow.implicitWidth + Spacing.md * 1.5
    implicitHeight: segRow.implicitHeight + 6

    // Concentric (h - 4) / 2 thumb radius (SPEC §2.1)
    radius: height * 0.5
    color: selected
        ? (Theme.isDark ? Qt.rgba(1, 1, 1, 0.16) : Theme.surface)
        : (hoverHandler.hovered ? Theme.controlFill : "transparent")
    border.color: selected && Appearance.shouldIncreaseContrast ? Theme.highContrastBorderColor : "transparent"
    border.width: selected && Appearance.shouldIncreaseContrast ? 1.0 : 0

    Accessible.role: Accessible.PageTab
    Accessible.name: text || iconName
    Accessible.selected: selected

    HoverHandler { id: hoverHandler }

    TapHandler {
        onTapped: {
            FocusModel.markPointerNavigation();
            if (segment.enabled) {
                var parentCtrl = segment.parent ? segment.parent.parent : null;
                if (parentCtrl && parentCtrl.selectIndex) {
                    for (var i = 0; i < segment.parent.children.length; ++i) {
                        if (segment.parent.children[i] === segment) {
                            parentCtrl.selectIndex(i);
                            break;
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        id: segRow
        x: Math.max(Spacing.xs, Math.round((parent.width - width) * 0.5))
        width: Math.min(implicitWidth, Math.max(0, parent.width - Spacing.xs * 2))
        height: parent.height
        spacing: Spacing.xs

        Icon {
            visible: segment.iconName !== ""
            name: segment.iconName
            size: 14
            Layout.preferredWidth: size
            Layout.preferredHeight: size
            fill: segment.selected ? 1 : 0
            color: segment.selected ? Theme.textPrimary : (segment.enabled ? Theme.textSecondary : Theme.textDisabled)
        }

        Text {
            id: segText
            visible: segment.text !== ""
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: segment.text
            font: Typography.body
            color: segment.selected ? Theme.textPrimary : (segment.enabled ? Theme.textSecondary : Theme.textDisabled)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    ToolTip {
        visible: hoverHandler.hovered && segText.truncated && segment.text !== ""
        text: segment.text
        delay: 400
    }
}
