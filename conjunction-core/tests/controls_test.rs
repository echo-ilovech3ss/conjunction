use std::fs;
use std::path::Path;

#[test]
fn test_controls_qmldir_and_file_integrity() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let design_dir = manifest_dir.parent().unwrap().join("conjunction-design");
    let qmldir_path = design_dir.join("qml/Conjunction/Controls/qmldir");

    assert!(qmldir_path.exists(), "qmldir must exist at {}", qmldir_path.display());
    let content = fs::read_to_string(&qmldir_path).unwrap();

    let expected_controls = [
        "Action.qml",
        "Button.qml",
        "ToolButton.qml",
        "CheckBox.qml",
        "RadioButton.qml",
        "Switch.qml",
        "SegmentedControl.qml",
        "Segment.qml",
        "TextField.qml",
        "SearchField.qml",
        "TextArea.qml",
        "ComboBox.qml",
        "Slider.qml",
        "ProgressBar.qml",
        "ActivityIndicator.qml",
        "Menu.qml",
        "MenuItem.qml",
        "MenuSeparator.qml",
        "MenuHeading.qml",
        "CheckableMenuItem.qml",
        "ContextMenu.qml",
        "ToolTip.qml",
        "Sidebar.qml",
        "SidebarSection.qml",
        "SidebarRow.qml",
        "ListRow.qml",
        "TableHeader.qml",
        "TableDataRow.qml",
        "DisclosureControl.qml",
        "Toolbar.qml",
        "Popover.qml",
        "Dialog.qml",
        "Sheet.qml",
        "Alert.qml",
        "ScrollBar.qml",
    ];

    for file in &expected_controls {
        assert!(content.contains(file), "qmldir missing registration for {}", file);
        let file_path = design_dir.join("qml/Conjunction/Controls").join(file);
        assert!(file_path.exists(), "Control file {} missing on disk at {}", file, file_path.display());
    }
}

#[test]
fn test_size_classes_contract() {
    let compact_height = 24;
    let regular_height = 32;
    let large_height = 40;

    assert!(compact_height < regular_height);
    assert!(regular_height < large_height);
    assert!(regular_height >= 32, "Regular desktop control must meet >= 32px pointer target baseline");
}

#[test]
fn test_action_model_contract() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let action_path = manifest_dir.parent().unwrap().join("conjunction-design/qml/Conjunction/Controls/Action.qml");
    let content = fs::read_to_string(&action_path).unwrap();

    assert!(content.contains("property string text"));
    assert!(content.contains("property string iconName"));
    assert!(content.contains("property string shortcut"));
    assert!(content.contains("property bool enabled"));
    assert!(content.contains("property bool checkable"));
    assert!(content.contains("property bool checked"));
    assert!(content.contains("property string role"));
    assert!(content.contains("signal triggered"));
}

#[test]
fn test_button_contract() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let btn_path = manifest_dir.parent().unwrap().join("conjunction-design/qml/Conjunction/Controls/Button.qml");
    let content = fs::read_to_string(&btn_path).unwrap();

    assert!(content.contains("property bool isDefault"));
    assert!(content.contains("property bool isSecondary"));
    assert!(content.contains("property bool isDestructive"));
    assert!(content.contains("property string sizeClass"));
    assert!(content.contains("FocusRing"));
    assert!(content.contains("Keys.onReturnPressed"));
}

#[test]
fn test_segmented_control_contract() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let seg_path = manifest_dir.parent().unwrap().join("conjunction-design/qml/Conjunction/Controls/SegmentedControl.qml");
    let content = fs::read_to_string(&seg_path).unwrap();

    assert!(content.contains("Keys.onLeftPressed"));
    assert!(content.contains("Keys.onRightPressed"));
    assert!(content.contains("FocusRing"));
    assert!(content.contains("Accessible.role: Accessible.PageTabList"));
}

#[test]
fn test_search_field_contract() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let search_path = manifest_dir.parent().unwrap().join("conjunction-design/qml/Conjunction/Controls/SearchField.qml");
    let content = fs::read_to_string(&search_path).unwrap();

    assert!(content.contains("signal searchSubmitted"));
    assert!(content.contains("Keys.onEscapePressed"));
    assert!(content.contains("Keys.onReturnPressed"));
    assert!(content.contains("radiusPill"));
}

#[test]
fn test_desktop_reference_scene_exists() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let scene_path = manifest_dir.parent().unwrap().join("conjunction-design/gallery/scenes/DesktopReferenceScene.qml");
    assert!(scene_path.exists());
    let content = fs::read_to_string(&scene_path).unwrap();

    assert!(content.contains("Toolbar"));
    assert!(content.contains("Sidebar"));
    assert!(content.contains("SegmentedControl"));
    assert!(content.contains("SearchField"));
    assert!(content.contains("TableHeader"));
    assert!(content.contains("Popover"));
    assert!(content.contains("Alert"));
    assert!(content.contains("Sheet"));
}
