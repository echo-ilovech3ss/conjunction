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
            "conj_cli_acc_{}_{}",
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
fn test_cli_acceptance_hello_app_and_malicious_bundle() {
    let t = TestFixture::new("acceptance");
    let hello_app = t.path.join("Hello.app");
    let info_path = hello_app.join("Contents/Info.toml");
    let exec_path = hello_app.join("Contents/Executable/hello");

    let manifest = r#"bundle_format = "conjunction.app/1"
id = "dev.conjunction.test.hello"
name = "Hello App"
version = "1.0.0"
executable = "Contents/Executable/hello"
architectures = ["x86_64"]
description = "A friendly acceptance test application."
"#;

    create_file(&info_path, manifest, false);
    create_file(&exec_path, "#!/bin/sh\necho 'Hello from Conjunction'\n", true);

    let conj_bundle_bin = env!("CARGO_BIN_EXE_conj-bundle");

    // 1. conj-bundle validate Hello.app -> succeeds
    let output_val = Command::new(conj_bundle_bin)
        .arg("validate")
        .arg(&hello_app)
        .output()
        .expect("should run conj-bundle validate");
    assert!(
        output_val.status.success(),
        "validate should succeed for Hello.app: {}",
        String::from_utf8_lossy(&output_val.stderr)
    );
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
    assert!(stdout_insp.contains("Application ID: dev.conjunction.test.hello"));
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
    create_file(&mal_info, mal_manifest, false);

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

    create_file(&outside_target, "#!/bin/sh\necho outside\n", true);
    let sym_manifest = r#"bundle_format = "conjunction.app/1"
id = "org.conjunction.symescape"
name = "Symlink Escape App"
version = "1.0.0"
executable = "Contents/Executable/link_out"
architectures = ["x86_64"]
"#;
    create_file(&sym_info, sym_manifest, false);
    fs::create_dir_all(sym_link.parent().unwrap()).unwrap();

    #[cfg(unix)]
    {
        std::os::unix::fs::symlink(&outside_target, &sym_link)
            .expect("should create external symlink for escape test");
        let output_sym = Command::new(conj_bundle_bin)
            .arg("validate")
            .arg(&sym_app)
            .output()
            .expect("should run conj-bundle validate on symlink escape");
        assert!(!output_sym.status.success(), "validate must fail for external symlink");
        let stderr_sym = String::from_utf8_lossy(&output_sym.stderr);
        assert!(
            stderr_sym.contains("escapes") || stderr_sym.contains("outside"),
            "unexpected stderr: {}",
            stderr_sym
        );
    }
}

#[test]
fn test_cli_seal_verify_quarantine_and_wrappers() {
    let t = TestFixture::new("cli_features");
    let conj_bundle_bin = env!("CARGO_BIN_EXE_conj-bundle");

    // 1. Universal bundle + seal + verify + tamper detection
    let uni_app = t.path.join("Universal.app");
    let manifest = r#"bundle_format = "conjunction.app/2"
id = "org.example.uni"
name = "Universal"
version = "1.0.0"
executable = "Contents/MacOS/uni"
architectures = ["x86_64", "aarch64"]
runtime = "conjunction-1"
"#;
    create_file(uni_app.join("Contents/Info.toml"), manifest, false);
    create_file(uni_app.join("Contents/MacOS/x86_64/uni"), "#!/bin/sh\necho x86\n", true);
    create_file(uni_app.join("Contents/MacOS/aarch64/uni"), "#!/bin/sh\necho arm\n", true);

    let seal_out = Command::new(conj_bundle_bin)
        .args(["seal"])
        .arg(&uni_app)
        .output()
        .unwrap();
    assert!(seal_out.status.success(), "seal failed: {}", String::from_utf8_lossy(&seal_out.stderr));

    let verify_out = Command::new(conj_bundle_bin)
        .args(["verify"])
        .arg(&uni_app)
        .output()
        .unwrap();
    assert!(verify_out.status.success(), "verify failed");

    // Optional OpenSSL signing test if openssl is available
    if let Ok(gen) = Command::new("openssl")
        .args(["genpkey", "-algorithm", "Ed25519", "-out"])
        .arg(t.path.join("priv.pem"))
        .output()
    {
        if gen.status.success() {
            let pub_res = Command::new("openssl")
                .args(["pkey", "-in"])
                .arg(t.path.join("priv.pem"))
                .args(["-pubout", "-out"])
                .arg(t.path.join("pub.pem"))
                .output()
                .unwrap();
            assert!(pub_res.status.success());

            let sign_out = Command::new(conj_bundle_bin)
                .args(["seal"])
                .arg(&uni_app)
                .arg("--key")
                .arg(t.path.join("priv.pem"))
                .output()
                .unwrap();
            assert!(sign_out.status.success(), "seal --key failed: {}", String::from_utf8_lossy(&sign_out.stderr));

            let ver_sig = Command::new(conj_bundle_bin)
                .args(["verify"])
                .arg(&uni_app)
                .arg("--pubkey")
                .arg(t.path.join("pub.pem"))
                .output()
                .unwrap();
            assert!(ver_sig.status.success(), "verify --pubkey failed");
        }
    }

    // Tamper triggers failure
    create_file(uni_app.join("Contents/MacOS/x86_64/uni"), "#!/bin/sh\necho hacked\n", true);
    let verify_bad = Command::new(conj_bundle_bin)
        .args(["verify"])
        .arg(&uni_app)
        .output()
        .unwrap();
    assert!(!verify_bad.status.success(), "tampered bundle must fail verify");

    // 2. Quarantine set/inspect/clear
    let q_out = Command::new(conj_bundle_bin)
        .args(["quarantine"])
        .arg(&uni_app)
        .args(["--url", "https://example.com/app.cdmg"])
        .output()
        .unwrap();
    assert!(q_out.status.success());

    let q_insp = Command::new(conj_bundle_bin)
        .args(["quarantine"])
        .arg(&uni_app)
        .output()
        .unwrap();
    assert!(String::from_utf8_lossy(&q_insp.stdout).contains("Quarantined: true"));

    let q_clr = Command::new(conj_bundle_bin)
        .args(["quarantine"])
        .arg(&uni_app)
        .arg("--clear")
        .output()
        .unwrap();
    assert!(q_clr.status.success());

    // 3. Wrap Flatpak & AppImage & Exe
    let fp_out = t.path.join("Firefox.app");
    let wrap_fp = Command::new(conj_bundle_bin)
        .args(["wrap-flatpak", "org.mozilla.firefox"])
        .arg(&fp_out)
        .output()
        .unwrap();
    assert!(wrap_fp.status.success(), "wrap-flatpak failed: {}", String::from_utf8_lossy(&wrap_fp.stderr));

    let fake_ai = t.path.join("Tool.AppImage");
    create_file(&fake_ai, "#!/bin/sh\necho ai\n", true);
    let ai_out = t.path.join("Tool.app");
    let wrap_ai = Command::new(conj_bundle_bin)
        .args(["wrap-appimage"])
        .arg(&fake_ai)
        .arg(&ai_out)
        .args(["--id", "org.example.tool", "--name", "Tool"])
        .output()
        .unwrap();
    assert!(wrap_ai.status.success(), "wrap-appimage failed: {}", String::from_utf8_lossy(&wrap_ai.stderr));

    let fake_exe = t.path.join("winhello.exe");
    create_file(&fake_exe, "MZfake", false);
    let win_out = t.path.join("WinHello.app");
    let wrap_win = Command::new(conj_bundle_bin)
        .args(["wrap-exe"])
        .arg(&fake_exe)
        .arg(&win_out)
        .args(["--id", "win.conjunction.hello", "--name", "WinHello"])
        .output()
        .unwrap();
    assert!(wrap_win.status.success(), "wrap-exe failed: {}", String::from_utf8_lossy(&wrap_win.stderr));
    assert!(win_out.join("Contents/WinePrefix/drive_c/Program Files/WinHello/winhello.exe").is_file());
}
