import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Conjunction.Design

ApplicationWindow {
    id: window
    width: 860
    height: 640
    minimumWidth: 640
    minimumHeight: 480
    visible: true
    title: "Conjunction Design Gallery"
    color: Theme.background

    LayoutMirroring.enabled: Appearance.isRTL
    LayoutMirroring.childrenInherit: true

    property string initialScene: "typography"
    property string screenshotPath: ""
    property bool autoCloseAfterScreenshot: false

    function configure(theme, rtl, reducedMotion, scale) {
        if (theme && theme !== "") {
            Appearance.setMode(theme);
        }
        if (rtl) {
            Appearance.setLayoutDirection(Qt.RightToLeft);
        }
        if (reducedMotion) {
            Appearance.setReducedMotion(true);
        }
        if (scale && scale !== "") {
            var s = parseFloat(scale);
            if (!isNaN(s) && s > 0) {
                Appearance.setFontScale(s);
            }
        }
    }

    // Function to grab scene screenshot
    function captureScreenshot(path, closeWhenDone) {
        screenshotPath = path;
        autoCloseAfterScreenshot = closeWhenDone;
        captureTimer.restart();
    }

    Timer {
        id: captureTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (window.screenshotPath !== "") {
                window.contentItem.grabToImage(function(result) {
                    result.saveToFile(window.screenshotPath);
                    console.log("Screenshot saved to " + window.screenshotPath);
                    if (window.autoCloseAfterScreenshot) {
                        Qt.quit();
                    }
                });
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Toolbar / Header
        Rectangle {
            Layout.fillWidth: true
            height: 52
            color: Theme.surface
            border.color: Theme.separator
            border.width: Geometry.separatorThickness

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Spacing.md
                anchors.rightMargin: Spacing.md
                spacing: Spacing.sm

                Icon {
                    name: "settings"
                    size: 20
                    color: Theme.accent
                }

                Text {
                    text: "Conjunction Design"
                    font: Typography.windowTitle
                    color: Theme.textPrimary
                }

                Item { Layout.fillWidth: true }

                // Theme Toggle
                Rectangle {
                    width: 100
                    height: Geometry.controlHeightSmall
                    radius: Geometry.radiusSmall
                    color: Theme.surfaceSecondary
                    border.color: Theme.separator
                    border.width: Geometry.separatorThickness

                    Text {
                        anchors.centerIn: parent
                        text: Appearance.isDark ? "Dark" : "Light"
                        font: Typography.caption
                        color: Theme.textPrimary
                    }

                    TapHandler {
                        onTapped: Appearance.toggleTheme()
                    }
                }

                // Reduced Motion Toggle
                Rectangle {
                    width: 110
                    height: Geometry.controlHeightSmall
                    radius: Geometry.radiusSmall
                    color: Appearance.reducedMotion ? Theme.destructive : Theme.surfaceSecondary
                    border.color: Theme.separator
                    border.width: Geometry.separatorThickness

                    Text {
                        anchors.centerIn: parent
                        text: Appearance.reducedMotion ? "Motion: Off" : "Motion: On"
                        font: Typography.caption
                        color: Appearance.reducedMotion ? Theme.destructiveText : Theme.textPrimary
                    }

                    TapHandler {
                        onTapped: Appearance.setReducedMotion(!Appearance.reducedMotion)
                    }
                }

                // RTL Toggle
                Rectangle {
                    width: 70
                    height: Geometry.controlHeightSmall
                    radius: Geometry.radiusSmall
                    color: Appearance.isRTL ? Theme.accent : Theme.surfaceSecondary
                    border.color: Theme.separator
                    border.width: Geometry.separatorThickness

                    Text {
                        anchors.centerIn: parent
                        text: Appearance.isRTL ? "RTL" : "LTR"
                        font: Typography.caption
                        color: Appearance.isRTL ? Theme.accentText : Theme.textPrimary
                    }

                    TapHandler {
                        onTapped: Appearance.toggleRTL()
                    }
                }
            }
        }

        // Body: Sidebar + Main Scene View
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Navigation Sidebar
            Rectangle {
                Layout.preferredWidth: 180
                Layout.fillHeight: true
                color: Theme.surfaceSecondary
                border.color: Theme.separator
                border.width: Geometry.separatorThickness

                ListView {
                    id: navList
                    anchors.fill: parent
                    anchors.margins: Spacing.xs
                    spacing: Spacing.xxs
                    clip: true

                    model: ListModel {
                        ListElement { name: "Desktop Ref"; sceneId: "desktop_reference"; iconName: "settings" }
                        ListElement { name: "Buttons"; sceneId: "controls_buttons"; iconName: "check" }
                        ListElement { name: "Toggles"; sceneId: "controls_toggles"; iconName: "settings" }
                        ListElement { name: "Text Inputs"; sceneId: "controls_inputs"; iconName: "search" }
                        ListElement { name: "Segmented"; sceneId: "controls_segmented"; iconName: "copy" }
                        ListElement { name: "Menus"; sceneId: "controls_menus"; iconName: "settings" }
                        ListElement { name: "Sidebar"; sceneId: "controls_sidebar"; iconName: "arrow-right" }
                        ListElement { name: "Lists & Tables"; sceneId: "controls_lists"; iconName: "copy" }
                        ListElement { name: "Toolbar"; sceneId: "controls_toolbar"; iconName: "settings" }
                        ListElement { name: "Popover"; sceneId: "controls_popover"; iconName: "refresh" }
                        ListElement { name: "Dialogs/Sheets"; sceneId: "controls_dialogs"; iconName: "warning" }
                        ListElement { name: "Progress/Slider"; sceneId: "controls_progress_slider"; iconName: "refresh" }
                        ListElement { name: "Accessibility"; sceneId: "controls_accessibility"; iconName: "check" }
                        ListElement { name: "Keyboard Test"; sceneId: "keyboard_workflow"; iconName: "check" }
                        ListElement { name: "Typography"; sceneId: "typography"; iconName: "copy" }
                        ListElement { name: "Colors"; sceneId: "colors"; iconName: "settings" }
                        ListElement { name: "Spacing"; sceneId: "spacing"; iconName: "arrow-right" }
                        ListElement { name: "Surfaces"; sceneId: "surfaces"; iconName: "refresh" }
                        ListElement { name: "Focus"; sceneId: "focus"; iconName: "check" }
                        ListElement { name: "Selection"; sceneId: "selection"; iconName: "check" }
                        ListElement { name: "States"; sceneId: "states"; iconName: "warning" }
                        ListElement { name: "Motion"; sceneId: "motion"; iconName: "refresh" }
                        ListElement { name: "Icons"; sceneId: "icons"; iconName: "search" }
                        ListElement { name: "Benchmark"; sceneId: "benchmark"; iconName: "settings" }
                    }

                    delegate: Rectangle {
                        id: navItem
                        width: navList.width
                        height: Geometry.controlHeightMedium
                        radius: Geometry.radiusSmall
                        property bool isCurrent: navList.currentIndex === index
                        color: isCurrent ? Theme.selection : (hoverHandler.hovered ? Theme.surface : "transparent")

                        HoverHandler { id: hoverHandler }

                        TapHandler {
                            onTapped: navList.currentIndex = index
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Spacing.sm
                            anchors.rightMargin: Spacing.sm
                            spacing: Spacing.sm

                            Icon {
                                name: iconName
                                size: 16
                                color: navItem.isCurrent ? Theme.accent : Theme.textSecondary
                            }

                            Text {
                                text: name
                                font: Typography.controlLabel
                                color: navItem.isCurrent ? Theme.selectionText : Theme.textPrimary
                            }
                        }
                    }
                }
            }

            // Main Scene Container
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.background

                Loader {
                    id: sceneLoader
                    anchors.fill: parent
                    anchors.margins: Spacing.md

                    source: {
                        var id = navList.model.get(navList.currentIndex).sceneId;
                        if (id === "desktop_reference") return "scenes/DesktopReferenceScene.qml";
                        if (id === "controls_buttons") return "scenes/ButtonsScene.qml";
                        if (id === "controls_toggles") return "scenes/TogglesScene.qml";
                        if (id === "controls_inputs") return "scenes/TextInputsScene.qml";
                        if (id === "controls_segmented") return "scenes/SegmentedScene.qml";
                        if (id === "controls_menus") return "scenes/MenusScene.qml";
                        if (id === "controls_sidebar") return "scenes/SidebarScene.qml";
                        if (id === "controls_lists") return "scenes/ListsScene.qml";
                        if (id === "controls_toolbar") return "scenes/ToolbarScene.qml";
                        if (id === "controls_popover") return "scenes/PopoverScene.qml";
                        if (id === "controls_dialogs") return "scenes/DialogsScene.qml";
                        if (id === "controls_progress_slider") return "scenes/ProgressSliderScene.qml";
                        if (id === "controls_accessibility") return "scenes/AccessibilityScene.qml";
                        if (id === "keyboard_workflow") return "scenes/KeyboardWorkflowScene.qml";
                        if (id === "typography") return "scenes/TypographyScene.qml";
                        if (id === "colors") return "scenes/ColorsScene.qml";
                        if (id === "spacing") return "scenes/SpacingScene.qml";
                        if (id === "surfaces") return "scenes/SurfacesScene.qml";
                        if (id === "focus") return "scenes/FocusScene.qml";
                        if (id === "selection") return "scenes/SelectionScene.qml";
                        if (id === "states") return "scenes/StatesScene.qml";
                        if (id === "motion") return "scenes/MotionScene.qml";
                        if (id === "icons") return "scenes/IconsScene.qml";
                        if (id === "benchmark") return "deterministic/DeterministicScene.qml";
                        return "scenes/DesktopReferenceScene.qml";
                    }
                }
            }
        }
    }

    function selectScene(sceneId) {
        for (var i = 0; i < navList.model.count; ++i) {
            if (navList.model.get(i).sceneId === sceneId) {
                navList.currentIndex = i;
                break;
            }
        }
    }

    Component.onCompleted: {
        if (initialScene !== "") {
            selectScene(initialScene);
        }
    }
}
