import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Conjunction.Design
import Conjunction.Controls as C

ApplicationWindow {
    id: window
    width: 1080
    height: 760
    minimumWidth: 720
    minimumHeight: 540
    visible: true
    title: "Conjunction Design Gallery"
    color: Theme.background

    LayoutMirroring.enabled: Appearance.isRTL
    LayoutMirroring.childrenInherit: true

    property string initialScene: "liquid_glass"
    property string screenshotPath: ""
    property bool autoCloseAfterScreenshot: false

    function setKeyboardFocusActive(active) {
        FocusModel.setKeyboardActive(!!active);
    }

    function configure(theme, rtl, reducedMotion, scale, reduceTransparency, increaseContrast) {
        if (theme && theme !== "") Appearance.setMode(theme);
        if (rtl !== undefined && rtl) Appearance.setLayoutDirection(Qt.RightToLeft);
        if (reducedMotion !== undefined) Appearance.setReducedMotion(!!reducedMotion);
        if (reduceTransparency !== undefined) Appearance.setReduceTransparency(!!reduceTransparency);
        if (increaseContrast !== undefined) Appearance.setIncreaseContrast(!!increaseContrast);
        if (scale && scale !== "") {
            var s = parseFloat(scale);
            if (!isNaN(s) && s > 0) Appearance.setFontScale(s);
        }
    }

    function captureScreenshot(path, closeWhenDone) {
        screenshotPath = path;
        autoCloseAfterScreenshot = closeWhenDone;
        captureTimer.restart();
    }

    Timer {
        id: captureTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (window.screenshotPath !== "") {
                window.contentItem.grabToImage(function(result) {
                    result.saveToFile(window.screenshotPath);
                    if (window.autoCloseAfterScreenshot) Qt.quit();
                });
            }
        }
    }

    readonly property bool isFullBleedCalibration: {
        var cur = navList.model.get(navList.currentIndex);
        return cur && cur.sceneId === "glass_calibration";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Toolbar / Header (hidden in pixel calibration scene so coordinates start cleanly at 0,0)
        C.Toolbar {
            Layout.fillWidth: true
            visible: !window.isFullBleedCalibration
            leadingItems: [
                Icon { name: "settings"; size: 18; color: Theme.accent },
                Text { text: "Conjunction Design"; font: Typography.windowTitle; color: Theme.textPrimary }
            ]
            trailingItems: [
                C.Button {
                    sizeClass: "pill"
                    text: Appearance.isDark ? "Dark" : "Light"
                    iconName: Appearance.isDark ? "moon" : "sun"
                    onClicked: Appearance.toggleTheme()
                },
                C.Button {
                    sizeClass: "pill"
                    text: Appearance.shouldReduceTransparency ? "Opaque" : "Glass"
                    isDefault: Appearance.shouldReduceTransparency
                    onClicked: Appearance.setReduceTransparency(!Appearance.reduceTransparency)
                },
                C.Button {
                    sizeClass: "pill"
                    text: Appearance.shouldIncreaseContrast ? "Contrast+" : "Contrast"
                    isDefault: Appearance.shouldIncreaseContrast
                    onClicked: Appearance.setIncreaseContrast(!Appearance.increaseContrast)
                },
                C.Button {
                    sizeClass: "pill"
                    text: Appearance.reducedMotion ? "Motion: Off" : "Motion: On"
                    isDestructive: Appearance.reducedMotion
                    onClicked: Appearance.setReducedMotion(!Appearance.reducedMotion)
                },
                C.Button {
                    sizeClass: "pill"
                    text: Appearance.isRTL ? "RTL" : "LTR"
                    onClicked: Appearance.toggleRTL()
                }
            ]
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            C.Sidebar {
                Layout.preferredWidth: 216
                Layout.fillHeight: true
                visible: !window.isFullBleedCalibration

                ListView {
                    id: navList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2
                    clip: true

                    model: ListModel {
                        ListElement { name: "Liquid Glass"; sceneId: "liquid_glass"; iconName: "desktop" }
                        ListElement { name: "Glass Calibration"; sceneId: "glass_calibration"; iconName: "sliders" }
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

                    delegate: C.SidebarRow {
                        width: navList.width
                        title: name
                        iconName: iconName
                        selected: navList.currentIndex === index
                        focusedSelection: selected
                        onRowClicked: navList.currentIndex = index
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.background

                Loader {
                    id: sceneLoader
                    anchors.fill: parent
                    anchors.margins: window.isFullBleedCalibration ? 0 : Spacing.lg

                    source: {
                        var id = navList.model.get(navList.currentIndex).sceneId;
                        if (id === "liquid_glass") return "scenes/LiquidGlassScene.qml";
                        if (id === "glass_calibration") return "scenes/GlassCalibrationScene.qml";
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
                        return "scenes/LiquidGlassScene.qml";
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
        if (initialScene !== "") selectScene(initialScene);
    }
}
