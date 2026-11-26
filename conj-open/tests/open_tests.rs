use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;

struct TestFixture {
    path: PathBuf,
}

impl TestFixture {
    fn new(name: &str) -> Self {
        let unique = format!(
            "conj_open_test_{}_{}",
            name,
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        );
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

fn write_exec<P: AsRef<Path>>(path: P, content: &str) {
    if let Some(p) = path.as_ref().parent() {
        fs::create_dir_all(p).unwrap();
    }
    let mut f = File::create(&path).unwrap();
    f.write_all(content.as_bytes()).unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&path, fs::Permissions::from_mode(0o755)).unwrap();
    }
}

#[test]
fn test_conj_open_launches_universal_bundle_with_frameworks_and_args() {
    let t = TestFixture::new("universal");
    let app = t.path.join("Universal.app");
    fs::create_dir_all(app.join("Contents/Frameworks")).unwrap();

    let host_arch = match std::env::consts::ARCH {
        "aarch64" => "aarch64",
        _ => "x86_64",
    };

    let manifest = r#"bundle_format = "conjunction.app/2"
id = "org.example.openuni"
name = "Open Uni"
version = "1.0.0"
executable = "Contents/MacOS/openuni"
architectures = ["x86_64", "aarch64"]
runtime = "conjunction-1"
"#;
    fs::create_dir_all(app.join("Contents")).unwrap();
    fs::write(app.join("Contents/Info.toml"), manifest).unwrap();

    // Create arch-specific entrypoints and verify host arch is selected
    write_exec(
        app.join("Contents/MacOS/x86_64/openuni"),
        "#!/bin/sh\necho \"ARCH=x86_64 ID=$CONJUNCTION_BUNDLE_ID FW=$LD_LIBRARY_PATH ARGS=$*\"\n",
    );
    write_exec(
        app.join("Contents/MacOS/aarch64/openuni"),
        "#!/bin/sh\necho \"ARCH=aarch64 ID=$CONJUNCTION_BUNDLE_ID FW=$LD_LIBRARY_PATH ARGS=$*\"\n",
    );

    let bin = env!("CARGO_BIN_EXE_conj-open");
    let out = Command::new(bin)
        .args(["--wait", "--bundle"])
        .arg(&app)
        .args(["--", "hello", "world"])
        .output()
        .expect("run conj-open");
    assert!(
        out.status.success(),
        "conj-open failed: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    let stdout = String::from_utf8_lossy(&out.stdout);
    assert!(
        stdout.contains(&format!("ARCH={}", host_arch)),
        "expected ARCH={}, got: {}",
        host_arch,
        stdout
    );
    assert!(stdout.contains("ID=org.example.openuni"), "stdout={}", stdout);
    assert!(stdout.contains("Contents/Frameworks"), "stdout={}", stdout);
    assert!(stdout.contains("ARGS=hello world"), "stdout={}", stdout);

    // Also verify passing file/URL arguments directly without `--` (like .desktop %U)
    let out_direct = Command::new(bin)
        .args(["--wait", "--bundle"])
        .arg(&app)
        .args(["/tmp/doc1.txt", "/tmp/doc2.txt"])
        .output()
        .expect("run conj-open with %U args");
    assert!(out_direct.status.success());
    let stdout_direct = String::from_utf8_lossy(&out_direct.stdout);
    assert!(
        stdout_direct.contains("ARGS=/tmp/doc1.txt /tmp/doc2.txt"),
        "stdout_direct={}",
        stdout_direct
    );
}

#[test]
fn test_conj_open_quarantine_gate_and_missing_arch_error() {
    let t = TestFixture::new("quarantine_arch");

    let app = t.path.join("Quarantined.app");
    let manifest = r#"bundle_format = "conjunction.app/2"
id = "org.example.qtest"
name = "Quarantined"
version = "1.0.0"
executable = "Contents/MacOS/qtest"
architectures = ["x86_64", "aarch64"]
runtime = "conjunction-1"
"#;
    fs::create_dir_all(app.join("Contents")).unwrap();
    fs::write(app.join("Contents/Info.toml"), manifest).unwrap();
    write_exec(app.join("Contents/MacOS/qtest"), "#!/bin/sh\necho launched-q\n");

    conjunction_core::security::set_quarantine(&app, Some("https://untrusted.example/app.cdmg"))
        .expect("set quarantine");

    let bin = env!("CARGO_BIN_EXE_conj-open");
    // Non-interactive without --allow-quarantined must fail
    let blocked = Command::new(bin)
        .args(["--wait", "--bundle"])
        .arg(&app)
        .output()
        .unwrap();
    assert!(!blocked.status.success(), "quarantined bundle must be blocked");
    let blocked_err = String::from_utf8_lossy(&blocked.stderr);
    assert!(blocked_err.contains("quarantined"), "stderr={}", blocked_err);

    // With --allow-quarantined it succeeds
    let allowed = Command::new(bin)
        .args(["--wait", "--allow-quarantined", "--bundle"])
        .arg(&app)
        .output()
        .unwrap();
    assert!(
        allowed.status.success(),
        "allowed quarantined failed: {}",
        String::from_utf8_lossy(&allowed.stderr)
    );
    assert!(String::from_utf8_lossy(&allowed.stdout).contains("launched-q"));

    // Wrong-arch bundle fails with clear error
    let other_arch = if std::env::consts::ARCH == "aarch64" {
        "x86_64"
    } else {
        "aarch64"
    };
    let wrong_app = t.path.join("WrongArch.app");
    let wrong_manifest = format!(
        r#"bundle_format = "conjunction.app/2"
id = "org.example.wrongarch"
name = "WrongArch"
version = "1.0.0"
executable = "Contents/MacOS/wrong"
architectures = ["{}"]
runtime = "conjunction-1"
"#,
        other_arch
    );
    fs::create_dir_all(wrong_app.join("Contents")).unwrap();
    fs::write(wrong_app.join("Contents/Info.toml"), wrong_manifest).unwrap();
    write_exec(
        wrong_app.join(format!("Contents/MacOS/{}/wrong", other_arch)),
        "#!/bin/sh\necho nope\n",
    );

    let wrong_out = Command::new(bin)
        .args(["--wait", "--bundle"])
        .arg(&wrong_app)
        .output()
        .unwrap();
    assert!(!wrong_out.status.success());
    let wrong_err = String::from_utf8_lossy(&wrong_out.stderr);
    assert!(
        wrong_err.contains("does not support host architecture") || wrong_err.contains("no executable found"),
        "stderr={}",
        wrong_err
    );
}
