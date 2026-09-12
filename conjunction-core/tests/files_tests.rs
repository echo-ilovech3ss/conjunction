use conjunction_core::files::{
    detect_mime_type, empty_trash, format_file_size, get_app_data_paths, move_to_trash,
    remove_app_data, FileItemInfo, QuickLookPreview, QuickLookType,
};
use std::fs;

#[test]
fn test_regular_file_item_info() {
    let tmp = std::env::temp_dir().join("conj_file_test_regular");
    let _ = fs::remove_dir_all(&tmp);
    fs::create_dir_all(&tmp).unwrap();

    let txt_path = tmp.join("notes.txt");
    fs::write(&txt_path, "Hello Conjunction Files").unwrap();

    let item = FileItemInfo::from_path(&txt_path).unwrap();
    assert_eq!(item.name, "notes.txt");
    assert!(!item.is_dir);
    assert!(!item.is_app_bundle);
    assert!(!item.can_show_package_contents);
    assert_eq!(item.mime_type, "text/plain");
    assert_eq!(item.size_bytes, 23);

    let _ = fs::remove_dir_all(&tmp);
}

#[test]
fn test_app_bundle_recognition_and_contents_inspection() {
    let tmp = std::env::temp_dir().join("conj_file_test_bundle");
    let _ = fs::remove_dir_all(&tmp);
    let bundle_path = tmp.join("Calculator.app");
    let contents = bundle_path.join("Contents");
    let macos = contents.join("MacOS");
    let resources = contents.join("Resources");

    fs::create_dir_all(&macos).unwrap();
    fs::create_dir_all(&resources).unwrap();

    let manifest = r#"
bundle_format = "conjunction.app/1"
id = "org.conjunction.calculator"
name = "Calculator"
version = "1.0.0"
executable = "Contents/MacOS/calculator"
architectures = ["x86_64", "aarch64"]
icon = "calc.png"
"#;
    fs::write(contents.join("Info.toml"), manifest).unwrap();

    let exec = macos.join("calculator");
    fs::write(&exec, "#!/bin/sh\necho calc\n").unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&exec, fs::Permissions::from_mode(0o755)).unwrap();
    }

    fs::write(resources.join("calc.png"), "dummy png data").unwrap();

    // Now inspect via FileItemInfo
    let item = FileItemInfo::from_path(&bundle_path).unwrap();
    assert_eq!(item.name, "Calculator.app");
    assert!(item.is_dir, "Underlying filesystem is a directory");
    assert!(item.is_app_bundle, "Recognized as application bundle object");
    assert!(item.can_show_package_contents, "Can show package contents");
    assert_eq!(item.bundle_id.as_deref(), Some("org.conjunction.calculator"));
    assert_eq!(item.bundle_name.as_deref(), Some("Calculator"));
    assert!(item.bundle_icon.is_some());
    assert_eq!(item.mime_type, "application/x-conjunction-app");

    // Test Quick Look on bundle
    let ql = QuickLookPreview::analyze(&bundle_path);
    assert_eq!(ql.preview_type, QuickLookType::AppBundle);
    assert_eq!(ql.name, "Calculator.app");
    assert_eq!(ql.metadata.get("Application ID").map(|s| s.as_str()), Some("org.conjunction.calculator"));
    assert_eq!(ql.metadata.get("Version").map(|s| s.as_str()), Some("1.0.0"));

    let _ = fs::remove_dir_all(&tmp);
}

#[test]
fn test_invalid_bundle_treated_as_normal_directory() {
    let tmp = std::env::temp_dir().join("conj_file_test_invalid_bundle");
    let _ = fs::remove_dir_all(&tmp);
    let fake_bundle = tmp.join("Malicious.app");
    fs::create_dir_all(&fake_bundle).unwrap();
    // Missing Contents / Info.toml

    let item = FileItemInfo::from_path(&fake_bundle).unwrap();
    assert!(item.is_dir);
    assert!(!item.is_app_bundle, "Invalid bundle must NOT be treated as valid application");
    assert!(!item.can_show_package_contents);

    let _ = fs::remove_dir_all(&tmp);
}

#[test]
fn test_quick_look_code_and_image_previews() {
    let tmp = std::env::temp_dir().join("conj_file_test_ql");
    let _ = fs::remove_dir_all(&tmp);
    fs::create_dir_all(&tmp).unwrap();

    let rust_file = tmp.join("sample.rs");
    fs::write(&rust_file, "fn main() {\n    println!(\"hi\");\n}\n").unwrap();

    let ql_code = QuickLookPreview::analyze(&rust_file);
    assert_eq!(ql_code.preview_type, QuickLookType::CodeText);
    assert!(ql_code.text_snippet.unwrap().contains("println"));

    let img_file = tmp.join("preview.png");
    fs::write(&img_file, "fake-png-bytes").unwrap();
    let ql_img = QuickLookPreview::analyze(&img_file);
    assert_eq!(ql_img.preview_type, QuickLookType::Image);

    let _ = fs::remove_dir_all(&tmp);
}

#[test]
fn test_app_data_path_resolution_and_cleanup() {
    let bundle_id = "org.conjunction.testapp";
    let paths = get_app_data_paths(bundle_id, true, Some(bundle_id));

    // Create mock config and cache dirs
    if let Some(config_path) = paths.iter().find(|p| p.to_string_lossy().contains(".config")) {
        let _ = fs::create_dir_all(config_path);
        assert!(config_path.exists());
    }

    let removed = remove_app_data(bundle_id, true, Some(bundle_id)).unwrap();
    assert!(removed >= 1, "Should have cleaned created app data directory");
}

#[test]
fn test_trash_spec_lifecycle() {
    let tmp = std::env::temp_dir().join("conj_file_test_trash");
    let _ = fs::remove_dir_all(&tmp);
    fs::create_dir_all(&tmp).unwrap();

    let target = tmp.join("trash_me.txt");
    fs::write(&target, "delete this content").unwrap();
    assert!(target.exists());

    let moved = move_to_trash(&target).unwrap();
    assert!(!target.exists(), "Original file should no longer exist");
    assert!(moved.exists(), "File should be in trash files directory");

    let count = empty_trash().unwrap();
    assert!(count >= 1, "Empty trash should remove the trashed file");
    assert!(!moved.exists(), "Trashed file should now be permanently deleted");

    let _ = fs::remove_dir_all(&tmp);
}
