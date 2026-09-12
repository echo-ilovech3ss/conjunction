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

    radius: Geometry.radiusSmall - 1
    color: selected ? Theme.surface : (hoverHandler.hovered ? Theme.surface : "transparent")
    border.color: selected ? Theme.separator : "transparent"
    border.width: selected ? Geometry.separatorThickness : 0

    Accessible.role: Accessible.PageTab
    Accessible.name: text || iconName
    Accessible.selected: selected

    HoverHandler { id: hoverHandler }

    TapHandler {
        onTapped: {
            if (segment.enabled) {
                var parentCtrl = segment.parent ? segment.parent.parent : null;
                if (parentCtrl && parentCtrl.selectIndex) {
                    var idx = -1;
                    for (var i = 0; i < segment.parent.children.length; ++i) {
                        if (segment.parent.children[i] === segment) {
                            idx = i;
                            break;
                        }
                    }
                    if (idx !== -1) parentCtrl.selectIndex(idx);
                }
            }
        }
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: Spacing.xs

        Icon {
            visible: segment.iconName !== ""
            name: segment.iconName
            size: 14
            color: segment.selected ? Theme.accent : (segment.enabled ? Theme.textPrimary : Theme.textDisabled)
        }

        Text {
            visible: segment.text !== ""
            text: segment.text
            font: Typography.controlLabel
            color: segment.selected ? Theme.textPrimary : (segment.enabled ? Theme.textSecondary : Theme.textDisabled)
        }
    }
}
