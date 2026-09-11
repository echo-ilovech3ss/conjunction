use conjunction_core::bundle::{Bundle, BundleError, CURRENT_BUNDLE_FORMAT};
use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};

struct TestDir {
    path: PathBuf,
}

impl TestDir {
    fn new(name: &str) -> Self {
        let unique = format!("conj_test_{}_{}", name, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos());
        let path = std::env::temp_dir().join(unique);
        fs::create_dir_all(&path).unwrap();
        TestDir { path }
    }
}

impl Drop for TestDir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.path);
    }
}

fn create_file<P: AsRef<Path>>(path: P, content: &str, executable: bool) {
    if let Some(parent) = path.as_ref().parent() {
        fs::create_dir_all(parent).unwrap();
    }
    let mut file = File::create(&path).unwrap();
    file.write_all(content.as_bytes()).unwrap();

    #[cfg(unix)]
    if executable {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(&path).unwrap().permissions();
        perms.set_mode(0o755);
        fs::set_permissions(&path, perms).unwrap();
    }
    #[cfg(not(unix))]
    let _ = executable;
}

#[test]
fn test_minimal_valid_bundle() {
    let t = TestDir::new("minimal_valid");
    let bundle_dir = t.path.join("Minimal.app");
    let info_path = bundle_dir.join("Contents/Info.toml");
    let exec_path = bundle_dir.join("Contents/Executable/minimal");

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.minimal"
name = "Minimal App"
version = "0.1.0"
executable = "Contents/Executable/minimal"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );

    create_file(&info_path, &manifest_content, false);
    create_file(&exec_path, "#!/bin/sh\necho ok\n", true);

    let bundle = Bundle::open(&bundle_dir).expect("should open valid bundle");
    assert_eq!(bundle.manifest().id, "org.example.minimal");
    assert_eq!(bundle.manifest().name, "Minimal App");
    bundle.validate().expect("validation should succeed");
    let resolved = bundle.executable_path().expect("should resolve executable");
    assert!(resolved.ends_with("minimal"));
}

#[test]
fn test_full_metadata_bundle() {
    let t = TestDir::new("full_valid");
    let bundle_dir = t.path.join("Full.app");
    let info_path = bundle_dir.join("Contents/Info.toml");
    let exec_path = bundle_dir.join("Contents/Executable/full");

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.full"
name = "Full App"
version = "1.2.3"
executable = "Contents/Executable/full"
architectures = ["x86_64", "aarch64"]
icon = "Contents/Icons/app.svg"
category = "Utility"
description = "A full test application."
mime_types = ["text/plain", "application/json"]
url_schemes = ["conjunction"]
permissions = ["network", "audio"]

[data]
config = "org.example.full"
data = "org.example.full"
"#,
        CURRENT_BUNDLE_FORMAT
    );

    create_file(&info_path, &manifest_content, false);
    create_file(&exec_path, "#!/bin/sh\necho ok\n", true);

    let bundle = Bundle::open(&bundle_dir).unwrap();
    bundle.validate().unwrap();
    assert_eq!(bundle.manifest().permissions.as_ref().unwrap().len(), 2);
}

#[test]
fn test_valid_unicode_display_name() {
    let t = TestDir::new("unicode_valid");
    let bundle_dir = t.path.join("Unicode.app");
    let info_path = bundle_dir.join("Contents/Info.toml");
    let exec_path = bundle_dir.join("Contents/Executable/run");

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.unicode"
name = "Café ☕ Conjunction 日本語"
version = "1.0.0"
executable = "Contents/Executable/run"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );

    create_file(&info_path, &manifest_content, false);
    create_file(&exec_path, "#!/bin/sh\necho ok\n", true);

    let bundle = Bundle::open(&bundle_dir).unwrap();
    assert_eq!(bundle.manifest().name, "Café ☕ Conjunction 日本語");
    bundle.validate().unwrap();
}

#[test]
fn test_valid_path_containing_spaces() {
    let t = TestDir::new("space_path_valid");
    let bundle_dir = t.path.join("My Cool Application.app");
    let info_path = bundle_dir.join("Contents/Info.toml");
    let exec_path = bundle_dir.join("Contents/Executable/my runner");

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.spaces"
name = "Spaces App"
version = "1.0.0"
executable = "Contents/Executable/my runner"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );

    create_file(&info_path, &manifest_content, false);
    create_file(&exec_path, "#!/bin/sh\necho ok\n", true);

    let bundle = Bundle::open(&bundle_dir).unwrap();
    bundle.validate().unwrap();
}

#[test]
fn test_valid_internal_symlink() {
    let t = TestDir::new("symlink_internal");
    let bundle_dir = t.path.join("Symlink.app");
    let info_path = bundle_dir.join("Contents/Info.toml");
    let actual_exec = bundle_dir.join("Contents/Executable/real_binary");
    let symlink_path = bundle_dir.join("Contents/Executable/symlink_entry");

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.symlink"
name = "Symlink App"
version = "1.0.0"
executable = "Contents/Executable/symlink_entry"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );

    create_file(&info_path, &manifest_content, false);
    create_file(&actual_exec, "#!/bin/sh\necho ok\n", true);

    #[cfg(unix)]
    {
        std::os::unix::fs::symlink(&actual_exec, &symlink_path).unwrap();
        let bundle = Bundle::open(&bundle_dir).unwrap();
        bundle.validate().unwrap();
    }
    #[cfg(windows)]
    {
        if std::os::windows::fs::symlink_file(&actual_exec, &symlink_path).is_ok() {
            let bundle = Bundle::open(&bundle_dir).unwrap();
            bundle.validate().unwrap();
        }
    }
}

#[test]
fn test_missing_info_toml() {
    let t = TestDir::new("missing_info");
    let bundle_dir = t.path.join("MissingInfo.app");
    fs::create_dir_all(bundle_dir.join("Contents")).unwrap();

    let res = Bundle::open(&bundle_dir);
    match res {
        Err(BundleError::MissingManifest(_)) => {}
        other => panic!("Expected MissingManifest, got {:?}", other),
    }
}

#[test]
fn test_malformed_toml() {
    let t = TestDir::new("malformed_toml");
    let bundle_dir = t.path.join("Malformed.app");
    let info_path = bundle_dir.join("Contents/Info.toml");
    create_file(&info_path, "invalid toml ::: = []", false);

    let res = Bundle::open(&bundle_dir);
    match res {
        Err(BundleError::MalformedManifest(_)) => {}
        other => panic!("Expected MalformedManifest, got {:?}", other),
    }
}

#[test]
fn test_unsupported_bundle_format() {
    let t = TestDir::new("unsupported_format");
    let bundle_dir = t.path.join("BadFormat.app");
    let info_path = bundle_dir.join("Contents/Info.toml");

    let manifest_content = r#"bundle_format = "conjunction.app/99"
id = "org.example.bad"
name = "Bad Format"
version = "1.0.0"
executable = "Contents/Executable/bad"
architectures = ["x86_64"]
"#;
    create_file(&info_path, manifest_content, false);

    let bundle = Bundle::open(&bundle_dir).unwrap();
    match bundle.validate() {
        Err(BundleError::UnsupportedFormatVersion(v)) => assert_eq!(v, "conjunction.app/99"),
        other => panic!("Expected UnsupportedFormatVersion, got {:?}", other),
    }
}

#[test]
fn test_invalid_application_ids() {
    let invalid_ids = [
        "",
        "   ",
        "singleword",
        ".leading.dot",
        "trailing.dot.",
        "consecutive..dots",
        "has whitespace.app",
        "has/slash.app",
        "has\\backslash.app",
        "-badprefix.app",
        "badsuffix-.app",
        "illegal$chars*.app",
    ];

    for id in invalid_ids {
        assert!(
            Bundle::validate_id(id).is_err(),
            "ID '{}' should be invalid",
            id
        );
    }
}

#[test]
fn test_missing_executable_file() {
    let t = TestDir::new("missing_exec_file");
    let bundle_dir = t.path.join("MissingExec.app");
    let info_path = bundle_dir.join("Contents/Info.toml");

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.noexec"
name = "No Exec File"
version = "1.0.0"
executable = "Contents/Executable/does_not_exist"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );
    create_file(&info_path, &manifest_content, false);

    let bundle = Bundle::open(&bundle_dir).unwrap();
    match bundle.validate() {
        Err(BundleError::MissingExecutableFile(_)) => {}
        other => panic!("Expected MissingExecutableFile, got {:?}", other),
    }
}

#[test]
fn test_absolute_executable_path_rejected() {
    let t = TestDir::new("abs_exec");
    let bundle_dir = t.path.join("AbsExec.app");
    let info_path = bundle_dir.join("Contents/Info.toml");

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.absexec"
name = "Abs Exec"
version = "1.0.0"
executable = "/bin/sh"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );
    create_file(&info_path, &manifest_content, false);

    let bundle = Bundle::open(&bundle_dir).unwrap();
    match bundle.validate() {
        Err(BundleError::AbsoluteExecutablePath(_)) => {}
        other => panic!("Expected AbsoluteExecutablePath, got {:?}", other),
    }
}

#[test]
fn test_traversal_dot_dot_rejected() {
    let t = TestDir::new("traversal_exec");
    let bundle_dir = t.path.join("Traversal.app");
    let info_path = bundle_dir.join("Contents/Info.toml");

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.traversal"
name = "Traversal Exec"
version = "1.0.0"
executable = "../../bin/sh"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );
    create_file(&info_path, &manifest_content, false);

    let bundle = Bundle::open(&bundle_dir).unwrap();
    match bundle.validate() {
        Err(BundleError::ExecutablePathTraversal(_)) => {}
        other => panic!("Expected ExecutablePathTraversal, got {:?}", other),
    }
}

#[test]
fn test_nested_traversal_rejected() {
    let t = TestDir::new("nested_traversal");
    let bundle_dir = t.path.join("NestedTraversal.app");
    let info_path = bundle_dir.join("Contents/Info.toml");

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.nested"
name = "Nested Traversal"
version = "1.0.0"
executable = "Contents/Executable/../../../etc/passwd"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );
    create_file(&info_path, &manifest_content, false);

    let bundle = Bundle::open(&bundle_dir).unwrap();
    match bundle.validate() {
        Err(BundleError::ExecutablePathTraversal(_)) => {}
        other => panic!("Expected ExecutablePathTraversal, got {:?}", other),
    }
}

#[test]
fn test_symlink_escaping_bundle_rejected() {
    let t = TestDir::new("symlink_escape");
    let bundle_dir = t.path.join("SymlinkEscape.app");
    let info_path = bundle_dir.join("Contents/Info.toml");
    let outside_file = t.path.join("external_secret.txt");
    let symlink_path = bundle_dir.join("Contents/Executable/escaped_link");

    create_file(&outside_file, "external secret", true);

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.symlinkescape"
name = "Escaped Symlink"
version = "1.0.0"
executable = "Contents/Executable/escaped_link"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );
    create_file(&info_path, &manifest_content, false);

    let created_symlink = {
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(&outside_file, &symlink_path).is_ok()
        }
        #[cfg(windows)]
        {
            std::os::windows::fs::symlink_file(&outside_file, &symlink_path).is_ok()
        }
    };

    if created_symlink {
        let bundle = Bundle::open(&bundle_dir).unwrap();
        match bundle.validate() {
            Err(BundleError::ExecutableEscapesBundle(_)) => {}
            other => panic!("Expected ExecutableEscapesBundle, got {:?}", other),
        }
    }
}

#[test]
fn test_executable_is_directory_rejected() {
    let t = TestDir::new("exec_is_dir");
    let bundle_dir = t.path.join("ExecIsDir.app");
    let info_path = bundle_dir.join("Contents/Info.toml");
    let dir_as_exec = bundle_dir.join("Contents/Executable/a_directory");

    fs::create_dir_all(&dir_as_exec).unwrap();

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.execdir"
name = "Exec Is Dir"
version = "1.0.0"
executable = "Contents/Executable/a_directory"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );
    create_file(&info_path, &manifest_content, false);

    let bundle = Bundle::open(&bundle_dir).unwrap();
    match bundle.validate() {
        Err(BundleError::ExecutableNotRegularFile(_)) => {}
        other => panic!("Expected ExecutableNotRegularFile, got {:?}", other),
    }
}

#[cfg(unix)]
#[test]
fn test_executable_lacks_permission_rejected() {
    let t = TestDir::new("exec_no_perm");
    let bundle_dir = t.path.join("NoPerm.app");
    let info_path = bundle_dir.join("Contents/Info.toml");
    let exec_path = bundle_dir.join("Contents/Executable/non_exec");

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.noperm"
name = "No Perm"
version = "1.0.0"
executable = "Contents/Executable/non_exec"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );
    create_file(&info_path, &manifest_content, false);
    create_file(&exec_path, "echo hi", false); // not executable (no 0o755)

    let bundle = Bundle::open(&bundle_dir).unwrap();
    match bundle.validate() {
        Err(BundleError::ExecutableNotExecutable(_)) => {}
        other => panic!("Expected ExecutableNotExecutable, got {:?}", other),
    }
}

#[test]
fn test_invalid_architecture_rejected() {
    let t = TestDir::new("invalid_arch");
    let bundle_dir = t.path.join("InvalidArch.app");
    let info_path = bundle_dir.join("Contents/Info.toml");
    let exec_path = bundle_dir.join("Contents/Executable/run");

    let manifest_content = format!(
        r#"bundle_format = "{}"
id = "org.example.badarch"
name = "Bad Arch"
version = "1.0.0"
executable = "Contents/Executable/run"
architectures = ["mips64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );
    create_file(&info_path, &manifest_content, false);
    create_file(&exec_path, "#!/bin/sh\necho ok\n", true);

    let bundle = Bundle::open(&bundle_dir).unwrap();
    match bundle.validate() {
        Err(BundleError::UnsupportedArchitecture(a)) => assert_eq!(a, "mips64"),
        other => panic!("Expected UnsupportedArchitecture, got {:?}", other),
    }
}
