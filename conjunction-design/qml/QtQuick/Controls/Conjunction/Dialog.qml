import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import Conjunction.Design

T.Dialog {
    id: control

    property string titleText: ""
    property string messageText: ""
    property string defaultButtonText: "OK"
    property string cancelButtonText: "Cancel"
    property bool isDestructive: false
    property Item invokerItem: null

    signal defaultTriggered()
    signal cancelTriggered()

    modal: true
    focus: true
    anchors.centerIn: parent
    closePolicy: T.Popup.CloseOnEscape


    background: Rectangle {
        color: "transparent"
    }

    dim: true
    T.Overlay.modal: Rectangle {
        color: "#40000000"
    }

    contentItem: Surface {
        elevation: "dialog"
        radius: Geometry.radiusLarge
        implicitWidth: 380
        implicitHeight: dialogLayout.implicitHeight + Spacing.lg * 2

        ColumnLayout {
            id: dialogLayout
            anchors.fill: parent
            anchors.margins: Spacing.lg
            spacing: Spacing.md

            Text {
                text: control.titleText
                font: Typography.windowTitle
                color: Theme.textPrimary
                Layout.fillWidth: true
            }

            Text {
                text: control.messageText
                font: Typography.body
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: Geometry.separatorThickness
                color: Theme.separator
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Spacing.sm

                Item { Layout.fillWidth: true }

                Button {
                    text: control.cancelButtonText
                    onClicked: {
                        control.cancelTriggered();
                        control.close();
                    }
                }

                Button {
                    id: defBtn
                    text: control.defaultButtonText
                    isDefault: !control.isDestructive
                    isDestructive: control.isDestructive
                    focus: true
                    onClicked: {
                        control.defaultTriggered();
                        control.close();
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: function(event) {
        control.cancelTriggered();
        control.close();
        event.accepted = true;
    }

    onOpened: {
        defBtn.forceActiveFocus();
    }

    onClosed: {
        if (invokerItem) invokerItem.forceActiveFocus();
    }
}
