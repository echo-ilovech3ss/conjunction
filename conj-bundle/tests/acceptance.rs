use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;

struct TestFixture {
    path: PathBuf,
}

impl TestFixture {
    fn new(name: &str) -> Self {
        let unique = format!("conj_cli_acc_{}_{}", name, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos());
        let path = std::env::temp_dir().join(unique);
        fs::create_dir_all(&path).unwrap();
        TestFixture { path }
    }
}

impl Drop for TestFixture {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.path);
    }
}

fn create_file<P: AsRef<Path>>(path: P, content: &str) {
    if let Some(parent) = path.as_ref().parent() {
        fs::create_dir_all(parent).unwrap();
    }
    let mut file = File::create(&path).unwrap();
    file.write_all(content.as_bytes()).unwrap();
}

#[test]
fn test_cli_acceptance_hello_app_and_malicious_bundle() {
    let t = TestFixture::new("acceptance");
    let hello_app = t.path.join("Hello.app");
    let info_path = hello_app.join("Contents/Info.toml");
    let exec_path = hello_app.join("Contents/Executable/hello");

    let manifest = r#"bundle_format = "conjunction.app/1"
id = "org.conjunction.hello"
name = "Hello App"
version = "1.0.0"
executable = "Contents/Executable/hello"
architectures = ["x86_64"]
description = "A friendly acceptance test application."
"#;

    create_file(&info_path, manifest);
    create_file(&exec_path, "Hello from Conjunction\n");

    let conj_bundle_bin = env!("CARGO_BIN_EXE_conj-bundle");

    // 1. conj-bundle validate Hello.app -> succeeds
    let output_val = Command::new(conj_bundle_bin)
        .arg("validate")
        .arg(&hello_app)
        .output()
        .expect("should run conj-bundle validate");
    assert!(output_val.status.success(), "validate should succeed for Hello.app");
    let stdout_val = String::from_utf8_lossy(&output_val.stdout);
    assert!(stdout_val.contains("Valid Conjunction application bundle"));

    // 2. conj-bundle inspect Hello.app -> shows metadata
    let output_insp = Command::new(conj_bundle_bin)
        .arg("inspect")
        .arg(&hello_app)
        .output()
        .expect("should run conj-bundle inspect");
    assert!(output_insp.status.success(), "inspect should succeed for Hello.app");
    let stdout_insp = String::from_utf8_lossy(&output_insp.stdout);
    assert!(stdout_insp.contains("Application ID: org.conjunction.hello"));
    assert!(stdout_insp.contains("Name:           Hello App"));
    assert!(stdout_insp.contains("Version:        1.0.0"));
    assert!(stdout_insp.contains("Bundle Format:  conjunction.app/1"));
    assert!(stdout_insp.contains("Architectures:  x86_64"));

    // 3. Malicious bundle test: executable = "../../bin/sh"
    let mal_app = t.path.join("Malicious.app");
    let mal_info = mal_app.join("Contents/Info.toml");
    let mal_manifest = r#"bundle_format = "conjunction.app/1"
id = "org.conjunction.malicious"
name = "Malicious App"
version = "1.0.0"
executable = "../../bin/sh"
architectures = ["x86_64"]
"#;
    create_file(&mal_info, mal_manifest);

    let output_mal = Command::new(conj_bundle_bin)
        .arg("validate")
        .arg(&mal_app)
        .output()
        .expect("should run conj-bundle validate");
    assert!(!output_mal.status.success(), "validate must fail for traversal");
    let stderr_mal = String::from_utf8_lossy(&output_mal.stderr);
    assert!(stderr_mal.contains("traversal") || stderr_mal.contains("escapes"));

    // 4. Malicious bundle test: external symlink escape
    let sym_app = t.path.join("SymEscape.app");
    let sym_info = sym_app.join("Contents/Info.toml");
    let outside_target = t.path.join("target_file.txt");
    let sym_link = sym_app.join("Contents/Executable/link_out");

    create_file(&outside_target, "outside");
    let sym_manifest = r#"bundle_format = "conjunction.app/1"
id = "org.conjunction.symescape"
name = "Symlink Escape App"
version = "1.0.0"
executable = "Contents/Executable/link_out"
architectures = ["x86_64"]
"#;
    create_file(&sym_info, sym_manifest);

    let symlink_created = {
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(&outside_target, &sym_link).is_ok()
        }
        #[cfg(windows)]
        {
            std::os::windows::fs::symlink_file(&outside_target, &sym_link).is_ok()
        }
    };

    if symlink_created {
        let output_sym = Command::new(conj_bundle_bin)
            .arg("validate")
            .arg(&sym_app)
            .output()
            .expect("should run conj-bundle validate on symlink escape");
        assert!(!output_sym.status.success(), "validate must fail for external symlink");
        let stderr_sym = String::from_utf8_lossy(&output_sym.stderr);
        assert!(stderr_sym.contains("escapes application bundle"));
    }
}
