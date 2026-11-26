use clap::{Parser, Subcommand, ValueEnum};
use conjunction_core::cdmg::{
    eject_cdmg, mount_cdmg, pack_cdmg, CdmgFilesystem, MountBackend, PackOptions,
};
use conjunction_core::registry::copy_dir_all;
use conjunction_core::security::{
    clear_quarantine, get_quarantine, seal_bundle_manifest, set_quarantine,
    sign_bundle_manifest, verify_bundle_manifest, verify_bundle_signature, MANIFEST_SHA256_REL,
    MANIFEST_SIG_REL,
};
use conjunction_core::{host_arch, Bundle, BUNDLE_FORMAT_V2};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

#[derive(Parser, Debug)]
#[command(
    name = "conj-bundle",
    version = "0.2.0",
    about = "Conjunction application bundle and .cdmg disk image tool"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(ValueEnum, Debug, Clone, Copy)]
enum FsArg {
    Squashfs,
    Erofs,
}

#[derive(ValueEnum, Debug, Clone, Copy)]
enum BackendArg {
    Auto,
    Squashfuse,
    Erofsfuse,
    Udisks2,
}

#[derive(Subcommand, Debug)]
enum Commands {
    #[command(about = "Validate a Conjunction .app bundle")]
    Validate {
        #[arg(help = "Path to .app bundle directory")]
        path: PathBuf,
        #[arg(long, help = "Require Contents/Manifest.sha256 to exist")]
        require_sealed: bool,
        #[arg(long, help = "Verify optional Contents/Manifest.sig against PEM public key")]
        pubkey: Option<PathBuf>,
    },

    #[command(about = "Inspect a Conjunction .app bundle metadata")]
    Inspect {
        #[arg(help = "Path to .app bundle directory")]
        path: PathBuf,
    },

    #[command(about = "Generate Contents/Manifest.sha256 (and optional Contents/Manifest.sig)")]
    Seal {
        #[arg(help = "Path to .app bundle directory")]
        path: PathBuf,
        #[arg(long, help = "OpenSSL PEM private key to sign Manifest.sha256")]
        key: Option<PathBuf>,
    },

    #[command(about = "Verify Contents/Manifest.sha256 (and optional Contents/Manifest.sig)")]
    Verify {
        #[arg(help = "Path to .app bundle directory")]
        path: PathBuf,
        #[arg(long, help = "OpenSSL PEM public key to verify Manifest.sig")]
        pubkey: Option<PathBuf>,
    },

    #[command(about = "Inspect, set, or clear quarantine extended attributes")]
    Quarantine {
        #[arg(help = "Path to .app bundle or .cdmg disk image")]
        path: PathBuf,
        #[arg(long, help = "Set quarantine with origin URL")]
        url: Option<String>,
        #[arg(long, help = "Set quarantine without origin URL")]
        set: bool,
        #[arg(long, help = "Clear quarantine flag")]
        clear: bool,
    },

    #[command(about = "Pack a .app bundle into a .cdmg disk image")]
    Pack {
        #[arg(help = "Path to .app bundle")]
        bundle: PathBuf,
        #[arg(help = "Output .cdmg disk image path")]
        output: PathBuf,
        #[arg(long, help = "Disk image volume name")]
        volume_name: Option<String>,
        #[arg(long, value_enum, default_value_t = FsArg::Squashfs, help = "Read-only filesystem format")]
        fs: FsArg,
        #[arg(long, default_value = "/Applications", help = "Target for Applications symlink inside image")]
        applications_target: String,
        #[arg(long, help = "Optional background image path")]
        background: Option<PathBuf>,
        #[arg(long, help = "Skip writing Contents/Manifest.sha256 before packing")]
        no_seal: bool,
        #[arg(long, help = "Optional OpenSSL PEM private key to sign the packed bundle")]
        key: Option<PathBuf>,
    },

    #[command(about = "Mount a .cdmg disk image read-only unprivileged")]
    Mount {
        #[arg(help = "Path to .cdmg disk image")]
        path: PathBuf,
        #[arg(long, value_enum, default_value_t = BackendArg::Auto, help = "Mount backend")]
        backend: BackendArg,
        #[arg(long, help = "Allow mounting quarantined disk image")]
        allow_quarantined: bool,
    },

    #[command(about = "Eject (unmount) a mounted .cdmg disk image")]
    Eject {
        #[arg(help = "Mount point, volume ID, or .cdmg path")]
        target: PathBuf,
    },

    #[command(about = "Wrap an AppImage into a Conjunction .app bundle")]
    WrapAppimage {
        #[arg(help = "Path to source .AppImage file")]
        appimage: PathBuf,
        #[arg(help = "Output .app directory")]
        output: PathBuf,
        #[arg(long, help = "Reverse-DNS bundle ID")]
        id: String,
        #[arg(long, help = "Display name")]
        name: String,
        #[arg(long, default_value = "1.0.0", help = "Version string")]
        version: String,
        #[arg(long, help = "Optional icon file to copy into Contents/Resources")]
        icon: Option<PathBuf>,
        #[arg(long, help = "Target architecture (defaults to host arch)")]
        arch: Option<String>,
    },

    #[command(about = "Create a thin Flatpak-backed Conjunction .app bundle")]
    WrapFlatpak {
        #[arg(help = "Flatpak application ID (e.g. org.mozilla.firefox)")]
        flatpak_id: String,
        #[arg(help = "Output .app directory")]
        output: PathBuf,
        #[arg(long, help = "Display name (defaults to last ID segment)")]
        name: Option<String>,
        #[arg(long, default_value = "user", help = "Flatpak scope: user or system")]
        scope: String,
        #[arg(long, default_value = "flathub", help = "Flatpak remote name")]
        remote: String,
        #[arg(long, default_value = "1.0.0", help = "Version string")]
        version: String,
        #[arg(long, help = "Optional icon file or theme name")]
        icon: Option<String>,
    },

    #[command(about = "Wrap a Windows .exe and self-contained Wine prefix into a .app bundle")]
    WrapExe {
        #[arg(help = "Path to Windows .exe file")]
        exe: PathBuf,
        #[arg(help = "Output .app directory")]
        output: PathBuf,
        #[arg(long, help = "Reverse-DNS bundle ID")]
        id: String,
        #[arg(long, help = "Display name")]
        name: String,
        #[arg(long, default_value = "1.0.0", help = "Version string")]
        version: String,
        #[arg(long, help = "Optional existing WINEPREFIX directory to bundle inside Contents/WinePrefix")]
        prefix_dir: Option<PathBuf>,
        #[arg(long, help = "Initialize WinePrefix with wineboot --init during bundle creation")]
        init_prefix: bool,
        #[arg(long, help = "Optional icon file (.png or .svg)")]
        icon: Option<PathBuf>,
    },
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    match cli.command {
        Commands::Validate {
            path,
            require_sealed,
            pubkey,
        } => match Bundle::open(&path) {
            Ok(bundle) => {
                if let Err(err) = bundle.validate() {
                    eprintln!("error: {}", err);
                    return ExitCode::FAILURE;
                }
                if require_sealed && !path.join(MANIFEST_SHA256_REL).is_file() {
                    eprintln!("error: bundle is not sealed (missing {})", MANIFEST_SHA256_REL);
                    return ExitCode::FAILURE;
                }
                if let Some(ref pk) = pubkey {
                    if let Err(e) = verify_bundle_signature(&path, pk) {
                        eprintln!("error: {}", e);
                        return ExitCode::FAILURE;
                    }
                }
                println!("Valid Conjunction application bundle");
                ExitCode::SUCCESS
            }
            Err(err) => {
                eprintln!("error: {}", err);
                ExitCode::FAILURE
            }
        },

        Commands::Inspect { path } => match Bundle::open(&path) {
            Ok(bundle) => {
                let m = bundle.manifest();
                println!("Application ID: {}", m.id);
                println!("Name:           {}", m.name);
                println!("Version:        {}", m.version);
                println!("Bundle Format:  {}", m.bundle_format);
                println!("Runtime:        {}", m.runtime.as_deref().unwrap_or("conjunction-1"));
                if let Some(min_os) = &m.minimum_os {
                    println!("Minimum OS:     {}", min_os);
                }
                println!("Executable:     {}", m.executable);
                println!("Architectures:  {}", m.architectures.join(", "));
                println!("Host Arch:      {}", host_arch());

                if let Some(desc) = &m.description {
                    println!("Description:    {}", desc);
                }
                if let Some(cat) = &m.category {
                    println!("Category:       {}", cat);
                }
                if let Some(icon) = &m.icon {
                    println!("Icon:           {}", icon);
                }
                let mimes = m.effective_mime_types();
                if !mimes.is_empty() {
                    println!("MIME Types:     {}", mimes.join(", "));
                }
                if let Some(schemes) = &m.url_schemes {
                    println!("URL Schemes:    {}", schemes.join(", "));
                }
                if let Some(perms) = &m.permissions {
                    println!("Permissions:    {}", perms.join(", "));
                }
                if let Ok(fw) = bundle.frameworks_dirs() {
                    if !fw.is_empty() {
                        let list: Vec<String> = fw.iter().map(|p| p.display().to_string()).collect();
                        println!("Frameworks:     {}", list.join(", "));
                    }
                }
                let sealed = path.join(MANIFEST_SHA256_REL).is_file();
                let signed = path.join(MANIFEST_SIG_REL).is_file();
                println!("Sealed:         {}", sealed);
                println!("Signed:         {}", signed);
                if let Ok(q) = get_quarantine(&path) {
                    println!("Quarantined:    {}", q.is_quarantined());
                }
                ExitCode::SUCCESS
            }
            Err(err) => {
                eprintln!("error: {}", err);
                ExitCode::FAILURE
            }
        },

        Commands::Seal { path, key } => {
            match Bundle::open(&path).and_then(|b| b.validate()) {
                Ok(()) => {}
                Err(err) => {
                    eprintln!("error: {}", err);
                    return ExitCode::FAILURE;
                }
            }
            match seal_bundle_manifest(&path) {
                Ok(mp) => println!("Sealed {}", mp.display()),
                Err(err) => {
                    eprintln!("error: {}", err);
                    return ExitCode::FAILURE;
                }
            }
            if let Some(ref priv_key) = key {
                match sign_bundle_manifest(&path, priv_key) {
                    Ok(sp) => println!("Signed {}", sp.display()),
                    Err(err) => {
                        eprintln!("error: {}", err);
                        return ExitCode::FAILURE;
                    }
                }
            }
            ExitCode::SUCCESS
        }

        Commands::Verify { path, pubkey } => {
            if let Err(err) = Bundle::open(&path).and_then(|b| b.validate()) {
                eprintln!("error: {}", err);
                return ExitCode::FAILURE;
            }
            match verify_bundle_manifest(&path) {
                Ok(count) => println!("Verified {} file(s) in {}", count, MANIFEST_SHA256_REL),
                Err(err) => {
                    eprintln!("error: {}", err);
                    return ExitCode::FAILURE;
                }
            }
            if let Some(ref pk) = pubkey {
                if let Err(err) = verify_bundle_signature(&path, pk) {
                    eprintln!("error: {}", err);
                    return ExitCode::FAILURE;
                }
                println!("Verified cryptographic signature {}", MANIFEST_SIG_REL);
            }
            ExitCode::SUCCESS
        }

        Commands::Quarantine {
            path,
            url,
            set,
            clear,
        } => {
            if clear {
                match clear_quarantine(&path) {
                    Ok(()) => {
                        println!("Cleared quarantine on {}", path.display());
                        ExitCode::SUCCESS
                    }
                    Err(e) => {
                        eprintln!("error: {}", e);
                        ExitCode::FAILURE
                    }
                }
            } else if set || url.is_some() {
                match set_quarantine(&path, url.as_deref()) {
                    Ok(()) => {
                        println!("Quarantined {}", path.display());
                        ExitCode::SUCCESS
                    }
                    Err(e) => {
                        eprintln!("error: {}", e);
                        ExitCode::FAILURE
                    }
                }
            } else {
                match get_quarantine(&path) {
                    Ok(info) => {
                        println!("Quarantined: {}", info.is_quarantined());
                        if let Some(q) = info.quarantine {
                            println!("Attr:        {}", q);
                        }
                        if let Some(u) = info.origin_url {
                            println!("Origin URL:  {}", u);
                        }
                        ExitCode::SUCCESS
                    }
                    Err(e) => {
                        eprintln!("error: {}", e);
                        ExitCode::FAILURE
                    }
                }
            }
        }

        Commands::Pack {
            bundle,
            output,
            volume_name,
            fs,
            applications_target,
            background,
            no_seal,
            key,
        } => {
            let opts = PackOptions {
                bundle_path: bundle,
                output_path: output,
                volume_name,
                filesystem: match fs {
                    FsArg::Squashfs => CdmgFilesystem::SquashFs,
                    FsArg::Erofs => CdmgFilesystem::Erofs,
                },
                applications_target,
                background,
                seal: !no_seal,
                sign_key: key,
            };
            match pack_cdmg(&opts) {
                Ok(out_path) => {
                    println!("Packed disk image: {}", out_path.display());
                    ExitCode::SUCCESS
                }
                Err(e) => {
                    eprintln!("error: {}", e);
                    ExitCode::FAILURE
                }
            }
        }

        Commands::Mount {
            path,
            backend,
            allow_quarantined,
        } => {
            if !allow_quarantined {
                if let Ok(q) = get_quarantine(&path) {
                    if q.is_quarantined() {
                        eprintln!(
                            "error: '{}' is quarantined (pass --allow-quarantined to override)",
                            path.display()
                        );
                        return ExitCode::FAILURE;
                    }
                }
            }
            let b = match backend {
                BackendArg::Auto => MountBackend::Auto,
                BackendArg::Squashfuse => MountBackend::SquashFuse,
                BackendArg::Erofsfuse => MountBackend::ErofsFuse,
                BackendArg::Udisks2 => MountBackend::Udisks2,
            };
            match mount_cdmg(&path, b) {
                Ok(rec) => {
                    println!("Mounted '{}' at {} ({})", rec.volume_name, rec.mount_point.display(), rec.backend);
                    ExitCode::SUCCESS
                }
                Err(e) => {
                    eprintln!("error: {}", e);
                    ExitCode::FAILURE
                }
            }
        }

        Commands::Eject { target } => match eject_cdmg(&target) {
            Ok(()) => {
                println!("Ejected {}", target.display());
                ExitCode::SUCCESS
            }
            Err(e) => {
                eprintln!("error: {}", e);
                ExitCode::FAILURE
            }
        },

        Commands::WrapAppimage {
            appimage,
            output,
            id,
            name,
            version,
            icon,
            arch,
        } => wrap_appimage_cmd(&appimage, &output, &id, &name, &version, icon.as_deref(), arch.as_deref()),

        Commands::WrapFlatpak {
            flatpak_id,
            output,
            name,
            scope,
            remote,
            version,
            icon,
        } => wrap_flatpak_cmd(&flatpak_id, &output, name.as_deref(), &scope, &remote, &version, icon.as_deref()),

        Commands::WrapExe {
            exe,
            output,
            id,
            name,
            version,
            prefix_dir,
            init_prefix,
            icon,
        } => wrap_exe_cmd(&exe, &output, &id, &name, &version, prefix_dir.as_deref(), init_prefix, icon.as_deref()),
    }
}

fn set_exec_perms(path: &Path) -> std::io::Result<()> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(path, fs::Permissions::from_mode(0o755))?;
    }
    Ok(())
}

fn wrap_appimage_cmd(
    appimage: &Path,
    output: &Path,
    id: &str,
    name: &str,
    version: &str,
    icon: Option<&Path>,
    arch: Option<&str>,
) -> ExitCode {
    if !appimage.is_file() {
        eprintln!("error: AppImage not found: {}", appimage.display());
        return ExitCode::FAILURE;
    }
    if let Err(e) = Bundle::validate_id(id) {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }

    let macos_dir = output.join("Contents/MacOS");
    let res_dir = output.join("Contents/Resources");
    if let Err(e) = fs::create_dir_all(&macos_dir).and_then(|_| fs::create_dir_all(&res_dir)) {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }

    let fname = appimage
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("app.AppImage");
    let dest_payload = macos_dir.join(fname);
    if let Err(e) = fs::copy(appimage, &dest_payload).and_then(|_| set_exec_perms(&dest_payload)) {
        eprintln!("error: failed to copy AppImage: {}", e);
        return ExitCode::FAILURE;
    }

    let icon_line = copy_optional_icon_file(icon, &res_dir);
    let target_arch = arch.unwrap_or_else(|| host_arch());
    let toml = format!(
        "bundle_format = \"{}\"\nid = \"{}\"\nname = \"{}\"\nversion = \"{}\"\nexecutable = \"Contents/MacOS/{}\"\narchitectures = [\"{}\"]\nruntime = \"appimage\"\n{}\n[appimage]\npayload = \"Contents/MacOS/{}\"\nextract_and_run_fallback = true\n",
        BUNDLE_FORMAT_V2, id, name, version, fname, target_arch, icon_line, fname
    );
    if let Err(e) = fs::write(output.join("Contents/Info.toml"), toml) {
        eprintln!("error: failed to write Info.toml: {}", e);
        return ExitCode::FAILURE;
    }
    if let Err(e) = Bundle::open(output).and_then(|b| b.validate()) {
        eprintln!("error: generated bundle validation failed: {}", e);
        return ExitCode::FAILURE;
    }
    println!("Created AppImage bundle: {}", output.display());
    ExitCode::SUCCESS
}

fn wrap_flatpak_cmd(
    flatpak_id: &str,
    output: &Path,
    name: Option<&str>,
    scope: &str,
    remote: &str,
    version: &str,
    icon: Option<&str>,
) -> ExitCode {
    if let Err(e) = Bundle::validate_id(flatpak_id) {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }
    if scope != "user" && scope != "system" {
        eprintln!("error: scope must be 'user' or 'system'");
        return ExitCode::FAILURE;
    }
    let display_name = name.unwrap_or_else(|| flatpak_id.split('.').next_back().unwrap_or(flatpak_id));
    let macos_dir = output.join("Contents/MacOS");
    let res_dir = output.join("Contents/Resources");
    if let Err(e) = fs::create_dir_all(&macos_dir).and_then(|_| fs::create_dir_all(&res_dir)) {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }

    let launcher = macos_dir.join("launch");
    let script = format!("#!/bin/sh\nexec flatpak run --{} {} \"$@\"\n", scope, flatpak_id);
    if let Err(e) = fs::write(&launcher, script).and_then(|_| set_exec_perms(&launcher)) {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }

    let icon_line = if let Some(ic) = icon {
        let ic_path = Path::new(ic);
        if ic_path.is_file() {
            copy_optional_icon_file(Some(ic_path), &res_dir)
        } else {
            format!("icon = \"{}\"\n", ic)
        }
    } else {
        format!("icon = \"{}\"\n", flatpak_id)
    };

    let toml = format!(
        "bundle_format = \"{}\"\nid = \"{}\"\nname = \"{}\"\nversion = \"{}\"\nexecutable = \"Contents/MacOS/launch\"\narchitectures = [\"x86_64\", \"aarch64\"]\nruntime = \"flatpak\"\n{}\n[flatpak]\nid = \"{}\"\nscope = \"{}\"\nremote = \"{}\"\n",
        BUNDLE_FORMAT_V2, flatpak_id, display_name, version, icon_line, flatpak_id, scope, remote
    );
    if let Err(e) = fs::write(output.join("Contents/Info.toml"), toml) {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }
    if let Err(e) = Bundle::open(output).and_then(|b| b.validate()) {
        eprintln!("error: generated bundle validation failed: {}", e);
        return ExitCode::FAILURE;
    }
    println!("Created Flatpak bundle: {}", output.display());
    ExitCode::SUCCESS
}

fn wrap_exe_cmd(
    exe: &Path,
    output: &Path,
    id: &str,
    name: &str,
    version: &str,
    prefix_dir: Option<&Path>,
    init_prefix: bool,
    icon: Option<&Path>,
) -> ExitCode {
    if !exe.is_file() {
        eprintln!("error: Windows executable not found: {}", exe.display());
        return ExitCode::FAILURE;
    }
    if let Err(e) = Bundle::validate_id(id) {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }

    let macos_dir = output.join("Contents/MacOS");
    let res_dir = output.join("Contents/Resources");
    let wine_prefix_dir = output.join("Contents/WinePrefix");
    if let Err(e) = fs::create_dir_all(&macos_dir)
        .and_then(|_| fs::create_dir_all(&res_dir))
        .and_then(|_| fs::create_dir_all(&wine_prefix_dir))
    {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }

    if let Some(src_prefix) = prefix_dir {
        if let Err(e) = copy_dir_all(src_prefix, &wine_prefix_dir) {
            eprintln!("error: failed to copy WINEPREFIX: {}", e);
            return ExitCode::FAILURE;
        }
    } else if init_prefix {
        let wineboot = Command::new("wineboot")
            .arg("--init")
            .env("WINEPREFIX", &wine_prefix_dir)
            .env("WINEARCH", "win64")
            .env("WINEDLLOVERRIDES", "winemenubuilder.exe=d")
            .env("DISPLAY", "")
            .output();
        if let Ok(out) = wineboot {
            if !out.status.success() {
                eprintln!(
                    "warning: wineboot --init exited with {}: {}",
                    out.status,
                    String::from_utf8_lossy(&out.stderr)
                );
            }
        }
    }

    let exe_name = exe.file_name().and_then(|s| s.to_str()).unwrap_or("app.exe");
    let clean_name: String = name
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() || c == '-' || c == '_' { c } else { '_' })
        .collect();
    let app_dir_in_c = wine_prefix_dir.join("drive_c/Program Files").join(&clean_name);
    if let Err(e) = fs::create_dir_all(&app_dir_in_c) {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }
    let dest_exe = app_dir_in_c.join(exe_name);
    if let Err(e) = fs::copy(exe, &dest_exe) {
        eprintln!("error: failed to copy .exe into WinePrefix: {}", e);
        return ExitCode::FAILURE;
    }
    let target_exe_rel = format!("Contents/WinePrefix/drive_c/Program Files/{}/{}", clean_name, exe_name);

    let launcher_name = if clean_name.is_empty() { "launch" } else { &clean_name };
    let launcher_path = macos_dir.join(launcher_name);
    let launcher_script = format!(
        "#!/bin/sh\nset -eu\nSELF_DIR=$(CDPATH= cd -- \"$(dirname -- \"$0\")\" && pwd)\nCONTENTS_DIR=$(CDPATH= cd -- \"$SELF_DIR/..\" && pwd)\nexport WINEPREFIX=\"${{WINEPREFIX:-$CONTENTS_DIR/WinePrefix}}\"\nexport WINEARCH=\"${{WINEARCH:-win64}}\"\nexport WINEDLLOVERRIDES=\"${{WINEDLLOVERRIDES:-winemenubuilder.exe=d}}\"\nexport WINEDEBUG=\"${{WINEDEBUG:--all}}\"\nexec wine \"$CONTENTS_DIR/WinePrefix/drive_c/Program Files/{}/{}\" \"$@\"\n",
        clean_name, exe_name
    );
    if let Err(e) = fs::write(&launcher_path, launcher_script).and_then(|_| set_exec_perms(&launcher_path)) {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }

    let icon_line = copy_optional_icon_file(icon, &res_dir);
    let toml = format!(
        "bundle_format = \"{}\"\nid = \"{}\"\nname = \"{}\"\nversion = \"{}\"\nexecutable = \"Contents/MacOS/{}\"\narchitectures = [\"x86_64\", \"aarch64\"]\nruntime = \"wine\"\n{}\n[wine]\nprefix = \"Contents/WinePrefix\"\ntarget_exe = \"{}\"\narch = \"win64\"\nesync = true\nfsync = true\nwine_debug = \"-all\"\n",
        BUNDLE_FORMAT_V2, id, name, version, launcher_name, icon_line, target_exe_rel
    );
    if let Err(e) = fs::write(output.join("Contents/Info.toml"), toml) {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }
    if let Err(e) = Bundle::open(output).and_then(|b| b.validate()) {
        eprintln!("error: generated bundle validation failed: {}", e);
        return ExitCode::FAILURE;
    }
    println!("Created Wine bundle: {}", output.display());
    ExitCode::SUCCESS
}

fn copy_optional_icon_file(icon: Option<&Path>, res_dir: &Path) -> String {
    let Some(src) = icon else {
        return String::new();
    };
    if !src.is_file() {
        return String::new();
    }
    let ext = src.extension().and_then(|e| e.to_str()).unwrap_or("png");
    let dest = res_dir.join(format!("icon.{}", ext));
    if fs::copy(src, &dest).is_ok() {
        format!("icon = \"Contents/Resources/icon.{}\"\n", ext)
    } else {
        String::new()
    }
}
