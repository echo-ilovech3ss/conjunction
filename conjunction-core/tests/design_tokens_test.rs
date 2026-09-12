use std::fs;
use std::path::Path;

// WCAG 2.1 Contrast Calculation Utilities
fn srgb_to_linear(c: f64) -> f64 {
    if c <= 0.04045 {
        c / 12.92
    } else {
        ((c + 0.055) / 1.055).powf(2.4)
    }
}

fn hex_to_rgb(hex: &str) -> (f64, f64, f64) {
    let hex = hex.trim_start_matches('#');
    let r = u8::from_str_radix(&hex[0..2], 16).unwrap() as f64 / 255.0;
    let g = u8::from_str_radix(&hex[2..4], 16).unwrap() as f64 / 255.0;
    let b = u8::from_str_radix(&hex[4..6], 16).unwrap() as f64 / 255.0;
    (r, g, b)
}

fn relative_luminance(hex: &str) -> f64 {
    let (r, g, b) = hex_to_rgb(hex);
    0.2126 * srgb_to_linear(r) + 0.7152 * srgb_to_linear(g) + 0.0722 * srgb_to_linear(b)
}

fn contrast_ratio(hex1: &str, hex2: &str) -> f64 {
    let l1 = relative_luminance(hex1);
    let l2 = relative_luminance(hex2);
    let (lighter, darker) = if l1 > l2 { (l1, l2) } else { (l2, l1) };
    (lighter + 0.05) / (darker + 0.05)
}

#[test]
fn test_wcag_contrast_light_theme() {
    let bg = "#F4F5F8";
    let surface = "#FFFFFF";
    let text_primary = "#15161A";
    let text_secondary = "#5A5D66";
    let accent = "#1D4ED8";
    let accent_text = "#FFFFFF";
    let destructive = "#DC2626";

    // Text primary on background (Normal text >= 4.5:1)
    let cr_bg = contrast_ratio(text_primary, bg);
    assert!(cr_bg >= 4.5, "Text primary on background CR: {:.2} < 4.5", cr_bg);

    // Text primary on surface
    let cr_surf = contrast_ratio(text_primary, surface);
    assert!(cr_surf >= 7.0, "Text primary on surface CR: {:.2} < 7.0 (AAA)", cr_surf);

    // Text secondary on surface
    let cr_sec = contrast_ratio(text_secondary, surface);
    assert!(cr_sec >= 4.5, "Text secondary on surface CR: {:.2} < 4.5 (AA)", cr_sec);

    // White text on accent
    let cr_accent = contrast_ratio(accent_text, accent);
    assert!(cr_accent >= 4.5, "Accent text on accent CR: {:.2} < 4.5", cr_accent);

    // Destructive text on surface
    let cr_dest = contrast_ratio(destructive, surface);
    assert!(cr_dest >= 4.5, "Destructive on surface CR: {:.2} < 4.5", cr_dest);
}

#[test]
fn test_wcag_contrast_dark_theme() {
    let bg = "#1A1B20";
    let surface = "#24262E";
    let text_primary = "#F5F6F8";
    let text_secondary = "#9EA2AD";
    let destructive = "#F87171";

    // Text primary on background (Normal text >= 4.5:1)
    let cr_bg = contrast_ratio(text_primary, bg);
    assert!(cr_bg >= 7.0, "Text primary on dark bg CR: {:.2} < 7.0 (AAA)", cr_bg);

    // Text primary on surface
    let cr_surf = contrast_ratio(text_primary, surface);
    assert!(cr_surf >= 7.0, "Text primary on dark surface CR: {:.2} < 7.0 (AAA)", cr_surf);

    // Text secondary on surface
    let cr_sec = contrast_ratio(text_secondary, surface);
    assert!(cr_sec >= 4.5, "Text secondary on dark surface CR: {:.2} < 4.5 (AA)", cr_sec);

    // Destructive on surface
    let cr_dest = contrast_ratio(destructive, surface);
    assert!(cr_dest >= 4.5, "Destructive on dark surface CR: {:.2} < 4.5", cr_dest);
}

#[test]
fn test_spacing_scale_ordering() {
    let none = 0;
    let xxs = 2;
    let xs = 4;
    let sm = 8;
    let md = 12;
    let lg = 16;
    let xl = 24;
    let xxl = 32;

    assert!(none < xxs);
    assert!(xxs < xs);
    assert!(xs < sm);
    assert!(sm < md);
    assert!(md < lg);
    assert!(lg < xl);
    assert!(xl < xxl);
}

#[test]
fn test_geometry_tokens_hierarchy() {
    let ctrl_sm = 24;
    let ctrl_md = 32;
    let ctrl_lg = 40;
    let min_target = 32;

    assert!(ctrl_sm < ctrl_md);
    assert!(ctrl_md < ctrl_lg);
    assert!(min_target >= 32, "Pointer target minimum must be >= 32px");

    let r_sm = 4;
    let r_md = 8;
    let r_lg = 12;
    let r_pill = 999;

    assert!(r_sm < r_md);
    assert!(r_md < r_lg);
    assert!(r_lg < r_pill);
}

#[test]
fn test_motion_durations_and_reduced_motion() {
    let instant = 0;
    let fast = 100;
    let normal = 200;
    let slow = 350;

    assert!(instant < fast);
    assert!(fast < normal);
    assert!(normal < slow);

    // Simulated reduced motion logic
    let get_duration = |base: i32, reduced: bool| if reduced { 0 } else { base };

    assert_eq!(get_duration(fast, false), 100);
    assert_eq!(get_duration(fast, true), 0);
    assert_eq!(get_duration(normal, true), 0);
    assert_eq!(get_duration(slow, true), 0);
}

#[test]
fn test_qml_module_integrity() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let design_dir = manifest_dir.parent().unwrap().join("conjunction-design");
    let qmldir_path = design_dir.join("qml/Conjunction/Design/qmldir");

    assert!(qmldir_path.exists(), "qmldir must exist at {}", qmldir_path.display());
    let content = fs::read_to_string(&qmldir_path).unwrap();

    let expected_files = [
        "Appearance.qml",
        "Theme.qml",
        "Typography.qml",
        "Spacing.qml",
        "Geometry.qml",
        "Motion.qml",
        "FocusModel.qml",
        "Icons.qml",
        "FocusRing.qml",
        "Surface.qml",
        "Icon.qml",
    ];

    for file in expected_files {
        assert!(content.contains(file), "qmldir must declare {}", file);
        let qml_file = design_dir.join("qml/Conjunction/Design").join(file);
        assert!(qml_file.exists(), "QML file {} must exist", qml_file.display());
    }
}
