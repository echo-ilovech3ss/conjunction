import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root

    property int currentIndex: 0
    property alias segments: segmentLayout.children
    default property alias data: segmentLayout.data

    signal segmentSelected(int index)

    implicitHeight: Geometry.controlHeightMedium
    implicitWidth: segmentLayout.implicitWidth + Spacing.xxs * 2

    radius: Geometry.radiusSmall
    color: Theme.surfaceSecondary
    border.color: Theme.separator
    border.width: Geometry.separatorThickness

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.PageTabList
    Accessible.focusable: true

    RowLayout {
        id: segmentLayout
        anchors.fill: parent
        anchors.margins: Spacing.xxs
        spacing: Spacing.xxs
    }

    FocusRing {
        active: root.activeFocus && FocusModel.keyboardNavigationActive
        target: root
    }

    Keys.onLeftPressed: function(event) {
        if (currentIndex > 0) {
            selectIndex(currentIndex - 1);
            event.accepted = true;
        }
    }
    Keys.onRightPressed: function(event) {
        if (currentIndex < segmentLayout.children.length - 1) {
            selectIndex(currentIndex + 1);
            event.accepted = true;
        }
    }

    function selectIndex(idx) {
        if (idx >= 0 && idx < segmentLayout.children.length) {
            currentIndex = idx;
            for (var i = 0; i < segmentLayout.children.length; ++i) {
                var child = segmentLayout.children[i];
                if (child.isSegment) {
                    child.selected = (i === idx);
                }
            }
            segmentSelected(idx);
        }
    }

    Component.onCompleted: {
        selectIndex(currentIndex);
    }
}
