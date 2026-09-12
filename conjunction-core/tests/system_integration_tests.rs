use conjunction_core::mime::{
    detect_mime, parse_mimeapps_file, resolve_default_handler, set_default_handler,
};
use std::fs;

#[test]
fn test_mime_detection() {
    let tmp = std::env::temp_dir().join("conj_test_mime_detect");
    let _ = fs::remove_dir_all(&tmp);
    fs::create_dir_all(&tmp).unwrap();

    let text_file = tmp.join("document.txt");
    fs::write(&text_file, "hello world").unwrap();

    let pdf_file = tmp.join("report.pdf");
    fs::write(&pdf_file, "%PDF-1.4").unwrap();

    let png_file = tmp.join("image.png");
    fs::write(&png_file, "fake png").unwrap();

    let sub_dir = tmp.join("My Folder");
    fs::create_dir(&sub_dir).unwrap();

    assert_eq!(detect_mime(&text_file), "text/plain");
    assert_eq!(detect_mime(&pdf_file), "application/pdf");
    assert_eq!(detect_mime(&png_file), "image/png");
    assert_eq!(detect_mime(&sub_dir), "inode/directory");

    let _ = fs::remove_dir_all(&tmp);
}

#[test]
fn test_mimeapps_parsing_and_resolution() {
    let tmp = std::env::temp_dir().join("conj_test_mime_parse");
    let _ = fs::remove_dir_all(&tmp);
    let config_dir = tmp.join(".config");
    fs::create_dir_all(&config_dir).unwrap();

    let mimeapps_path = config_dir.join("mimeapps.list");
    let content = r#"
# Standard FreeDesktop MIME associations
[Default Applications]
text/plain=org.kde.kwrite.desktop;
application/pdf=org.kde.okular.desktop
x-scheme-handler/http=zen.desktop
x-scheme-handler/https=zen.desktop

[Added Associations]
text/plain=org.kde.kwrite.desktop;zen.desktop;
"#;
    fs::write(&mimeapps_path, content).unwrap();

    let parsed = parse_mimeapps_file(&mimeapps_path);
    assert_eq!(
        parsed.get("text/plain"),
        Some(&vec!["org.kde.kwrite.desktop".to_string()])
    );
    assert_eq!(
        parsed.get("application/pdf"),
        Some(&vec!["org.kde.okular.desktop".to_string()])
    );
    assert_eq!(
        parsed.get("x-scheme-handler/http"),
        Some(&vec!["zen.desktop".to_string()])
    );

    let res = resolve_default_handler("text/plain", &tmp);
    assert_eq!(res, Some("org.kde.kwrite.desktop".to_string()));

    let res_http = resolve_default_handler("x-scheme-handler/http", &tmp);
    assert_eq!(res_http, Some("zen.desktop".to_string()));

    let _ = fs::remove_dir_all(&tmp);
}

#[test]
fn test_set_default_handler_mutation() {
    let tmp = std::env::temp_dir().join("conj_test_mime_mutation");
    let _ = fs::remove_dir_all(&tmp);
    fs::create_dir_all(&tmp).unwrap();

    // 1. Set initial default
    set_default_handler("text/plain", "custom-editor.desktop", &tmp).unwrap();
    assert_eq!(
        resolve_default_handler("text/plain", &tmp),
        Some("custom-editor.desktop".to_string())
    );

    // 2. Add another default
    set_default_handler("x-scheme-handler/http", "zen.desktop", &tmp).unwrap();
    assert_eq!(
        resolve_default_handler("x-scheme-handler/http", &tmp),
        Some("zen.desktop".to_string())
    );
    // Previous still persists
    assert_eq!(
        resolve_default_handler("text/plain", &tmp),
        Some("custom-editor.desktop".to_string())
    );

    // 3. Mutate existing default
    set_default_handler("text/plain", "org.kde.kate.desktop", &tmp).unwrap();
    assert_eq!(
        resolve_default_handler("text/plain", &tmp),
        Some("org.kde.kate.desktop".to_string())
    );

    let _ = fs::remove_dir_all(&tmp);
}

#[test]
fn test_scheme_handler_fallback() {
    let tmp = std::env::temp_dir().join("conj_test_scheme_fallback");
    let _ = fs::remove_dir_all(&tmp);
    fs::create_dir_all(&tmp).unwrap();

    // Nonexistent scheme returns None
    assert_eq!(resolve_default_handler("x-scheme-handler/custom-unknown", &tmp), None);

    // Add and resolve
    set_default_handler("x-scheme-handler/mailto", "thunderbird.desktop", &tmp).unwrap();
    assert_eq!(
        resolve_default_handler("x-scheme-handler/mailto", &tmp),
        Some("thunderbird.desktop".to_string())
    );

    let _ = fs::remove_dir_all(&tmp);
}
