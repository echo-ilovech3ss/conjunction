import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root

    property string title: ""
    property bool expanded: false

    signal toggled(bool isExpanded)

    implicitWidth: parent ? parent.width : 200
    implicitHeight: Math.max(Geometry.controlHeightMedium, discText.implicitHeight + 6)
    radius: Geometry.radiusSmall
    color: hoverHandler.hovered ? Theme.surfaceSecondary : "transparent"

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.focusable: true

    HoverHandler { id: hoverHandler }
    TapHandler {
        onTapped: {
            root.expanded = !root.expanded;
            root.toggled(root.expanded);
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Spacing.sm
        anchors.rightMargin: Spacing.sm
        spacing: Spacing.sm

        Icon {
            name: "arrow-right"
            size: 14
            color: Theme.textSecondary
            rotation: root.expanded ? 90 : 0

            Behavior on rotation {
                NumberAnimation { duration: Motion.duration(Motion.fast); easing.type: Motion.easingStandard }
            }
        }

        Text {
            id: discText
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.title
            font: Typography.controlLabel
            color: Theme.textPrimary
            elide: Text.ElideRight
        }
    }

    ToolTip {
        visible: hoverHandler.hovered && discText.truncated && root.title !== ""
        text: root.title
        delay: 400
    }

    FocusRing {
        active: root.activeFocus && FocusModel.keyboardNavigationActive
        target: root
    }

    Keys.onRightPressed: function(event) {
        if (!root.expanded) {
            root.expanded = true;
            root.toggled(true);
            event.accepted = true;
        }
    }
    Keys.onLeftPressed: function(event) {
        if (root.expanded) {
            root.expanded = false;
            root.toggled(false);
            event.accepted = true;
        }
    }
    Keys.onSpacePressed: function(event) {
        root.expanded = !root.expanded;
        root.toggled(root.expanded);
        event.accepted = true;
    }
}
