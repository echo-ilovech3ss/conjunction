import QtQuick
import QtQuick.Layouts
import Conjunction.Design

Rectangle {
    id: root

    // SPEC §2.1 & §2.3: regular 24pt (toolbar 25pt), small 21pt, mini 16pt (18pt), large 40pt
    property string sizeClass: "regular"
    property bool inToolbar: false
    property int currentIndex: 0
    property alias segments: segmentLayout.children
    default property alias data: segmentLayout.data

    signal segmentSelected(int index)

    readonly property int targetHeight: Geometry.segmentedHeight(sizeClass, inToolbar)

    implicitHeight: targetHeight
    implicitWidth: segmentLayout.implicitWidth + Spacing.xxs * 2

    radius: targetHeight * 0.5
    color: Theme.controlFill
    border.color: Appearance.shouldIncreaseContrast ? Theme.highContrastBorderColor : Theme.separator
    border.width: Geometry.separatorThickness

    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.PageTabList
    Accessible.focusable: true

    RowLayout {
        id: segmentLayout
        anchors.fill: parent
        anchors.margins: Spacing.xxs // 2 pt internal inset
        spacing: Spacing.xxs
    }

    FocusRing {
        target: root
        isTextInput: false
    }

    Keys.onLeftPressed: function(event) {
        FocusModel.markKeyboardNavigation();
        if (currentIndex > 0) {
            selectIndex(currentIndex - 1);
            event.accepted = true;
        }
    }
    Keys.onRightPressed: function(event) {
        FocusModel.markKeyboardNavigation();
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

    Component.onCompleted: selectIndex(currentIndex)
}
