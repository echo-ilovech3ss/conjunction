import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0b0d13"

    // Background Gradient with subtle violet glow matching Conjunction theme
    RadialGradient {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1c1836" }
            GradientStop { position: 0.5; color: "#10121d" }
            GradientStop { position: 1.0; color: "#08090d" }
        }
    }

    // Time & Date Header
    ColumnLayout {
        anchors.top: parent.top
        anchors.topMargin: 80
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Text {
            id: timeText
            Layout.alignment: Qt.AlignHCenter
            color: "#f1f5f9"
            font.pixelSize: 64
            font.weight: Font.DemiBold
            font.family: config.fontFamily || "Inter, system-ui, sans-serif"
            text: Qt.formatTime(new Date(), "HH:mm")
        }

        Text {
            id: dateText
            Layout.alignment: Qt.AlignHCenter
            color: "#94a3b8"
            font.pixelSize: 18
            font.weight: Font.Normal
            font.family: config.fontFamily || "Inter, system-ui, sans-serif"
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                timeText.text = Qt.formatTime(new Date(), "HH:mm")
                dateText.text = Qt.formatDate(new Date(), "dddd, MMMM d")
            }
        }
    }

    // Central Login Card
    Rectangle {
        id: loginCard
        width: 360
        height: 380
        anchors.centerIn: parent
        color: "#161923cc"
        radius: 20
        border.color: "#ffffff18"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 16

            // User Avatar Circle
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 72
                height: 72
                radius: 36
                color: "#7c5cfc25"
                border.color: "#7c5cfc"
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: (userModel.lastUser ? userModel.lastUser.charAt(0).toUpperCase() : "C")
                    color: "#f8fafc"
                    font.pixelSize: 32
                    font.weight: Font.Bold
                }
            }

            // Username Label or Selector
            Text {
                id: userNameText
                Layout.alignment: Qt.AlignHCenter
                text: userModel.lastUser || "User"
                color: "#f8fafc"
                font.pixelSize: 18
                font.weight: Font.Medium
                font.family: config.fontFamily || "Inter, system-ui, sans-serif"
            }

            // Password Input Box
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 12
                color: "#0f121a"
                border.color: passwordField.activeFocus ? "#7c5cfc" : "#334155"
                border.width: 1

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: "#f8fafc"
                    font.pixelSize: 14
                    focus: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Enter password"
                        color: "#64748b"
                        font.pixelSize: 14
                        visible: !passwordField.text && !passwordField.activeFocus
                    }

                    Keys.onReturnPressed: doLogin()
                    Keys.onEnterPressed: doLogin()
                }
            }

            // Error Text
            Text {
                id: errorMessage
                Layout.alignment: Qt.AlignHCenter
                text: ""
                color: "#f87171"
                font.pixelSize: 13
                visible: text.length > 0
            }

            // Login Button
            Button {
                id: loginButton
                Layout.fillWidth: true
                height: 44
                text: "Log In"
                onClicked: doLogin()

                contentItem: Text {
                    text: loginButton.text
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 12
                    color: loginButton.down ? "#6947eb" : (loginButton.hovered ? "#8b6dfd" : "#7c5cfc")
                }
            }

            // Session Selector
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                    text: "Session:"
                    color: "#94a3b8"
                    font.pixelSize: 12
                }

                ComboBox {
                    id: sessionSelector
                    model: sessionModel
                    textRole: "name"
                    currentIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

                    contentItem: Text {
                        text: sessionSelector.displayText
                        color: "#e2e8f0"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: "transparent"
                    }
                }
            }
        }
    }

    // Bottom Branding
    RowLayout {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 32
        spacing: 12

        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: "#7c5cfc"
        }

        Text {
            text: "Conjunction Linux"
            color: "#64748b"
            font.pixelSize: 14
            font.weight: Font.Medium
            font.family: config.fontFamily || "Inter, system-ui, sans-serif"
        }
    }

    // Bottom Power Actions
    RowLayout {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.right: parent.right
        anchors.rightMargin: 32
        spacing: 16

        Button {
            text: "Sleep"
            visible: sddm.canSuspend
            onClicked: sddm.suspend()
            contentItem: Text { text: "Sleep"; color: "#94a3b8"; font.pixelSize: 13 }
            background: Item {}
        }

        Button {
            text: "Restart"
            visible: sddm.canReboot
            onClicked: sddm.reboot()
            contentItem: Text { text: "Restart"; color: "#94a3b8"; font.pixelSize: 13 }
            background: Item {}
        }

        Button {
            text: "Shut Down"
            visible: sddm.canPowerOff
            onClicked: sddm.powerOff()
            contentItem: Text { text: "Shut Down"; color: "#94a3b8"; font.pixelSize: 13 }
            background: Item {}
        }
    }

    function doLogin() {
        errorMessage.text = ""
        var user = userModel.lastUser || (userModel.count > 0 ? userModel.data(userModel.index(0, 0), Qt.DisplayRole) : "")
        var sessionIndex = sessionSelector.currentIndex >= 0 ? sessionSelector.currentIndex : 0
        sddm.login(user, passwordField.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            errorMessage.text = "Incorrect password. Please try again."
            passwordField.selectAll()
            passwordField.forceActiveFocus()
        }
        function onLoginSucceeded() {
            errorMessage.text = ""
        }
    }

    Component.onCompleted: {
        passwordField.forceActiveFocus()
    }
}
