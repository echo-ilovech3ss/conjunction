import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: segment

    readonly property bool isSegment: true
    property string text: ""
    property string iconName: ""
    property bool selected: false
    property bool enabled: true

    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitWidth: segRow.implicitWidth + Spacing.md * 1.5

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
        anchors.centerIn: parent
        spacing: Spacing.xs

        Icon {
            visible: segment.iconName !== ""
            name: segment.iconName
            size: 14
            fill: segment.selected ? 1 : 0
            color: segment.selected ? Theme.textPrimary : (segment.enabled ? Theme.textSecondary : Theme.textDisabled)
        }

        Text {
            visible: segment.text !== ""
            text: segment.text
            font: Typography.body
            color: segment.selected ? Theme.textPrimary : (segment.enabled ? Theme.textSecondary : Theme.textDisabled)
        }
    }
}
