# Conjunction Application Bundles & Disk Images Specification

* **Format Version**: `conjunction.app/2` (backward compatible with `conjunction.app/1`)
* **Disk Image Format**: `conjunction.cdmg/1` (`.cdmg`, MIME `application/x-conjunction-disk-image`)
* **Target Base OS**: Conjunction on Fedora Atomic (bootc) KDE Plasma 6 (`x86_64`, `aarch64`)

---

## 1. Overview & Drag-and-Drop Contract

On Conjunction, every application is a single directory named `<Name>.app`:
* **Install**: Drag `<Name>.app` into `~/Applications` (user) or `/Applications` (system-wide).
* **Uninstall**: Delete `<Name>.app` (Move to Trash or `rm -rf`). No uninstaller or package-manager command is needed for native, AppImage, or Wine bundles. Deleting the bundle immediately deletes the executable and all bundled contents; only user-owned caches/configs remain (and are tracked for optional purge in Settings).
* **Running Apps**: A running application whose `.app` bundle is deleted keeps running until quit (Linux VFS retains open binary/library inodes until process exit, and `conj-open` uses `exec` without retaining a supervising wrapper).

### 1.1 Why the Previous Implementation Failed

1. **Broken acceptance test & conflicting formats**: `test_cli_acceptance_hello_app_and_malicious_bundle` failed because the fixture wrote `Hello.app/Contents/Executable/hello` without `0o755` execute bits and attempted symlink creation in `SymEscape.app` before creating `Contents/Executable/`. Simultaneously, three incompatible codepaths disagreed on bundle layout (`conjunction-core` used `Info.toml` + `Contents/Executable/`, while `cj`, `app_sync`, and `conjunction-core/src/lib.rs` generated `Info.plist` + `/Applications/*.desktop`).
2. **Stale cache & broken discovery**: `conj-appd` lacked an `inotify` watcher, reloaded stale `registry.json` on startup, scrubbed only in-memory `self.active` entries (orphaning `.desktop` and `mimeapps.list` across restarts), ignored `url_schemes`, used relative `Icon=` paths, and blocked on `cmd.output()` instead of `exec`-ing apps. Meanwhile `app_sync` polled `/Applications` every 3s and deleted `.app` folders lacking a legacy `.desktop` file.
3. **Missing runtime/ecosystem pieces**: There was no `Contents/Frameworks/` `LD_LIBRARY_PATH` setup, no `x86_64`/`aarch64` universal binary selection, no AppImage/Flatpak-on-delete integration, external Wine prefixes leaked into `~/.conjunction/prefixes/<app>` instead of inside `Contents/WinePrefix/`, and there were no `.cdmg` disk images, leftover tracking, quarantine xattrs, integrity manifests, or Dolphin KF6 plugins.

---

## 2. Bundle Directory Format

```text
Example.app/
└── Contents/
    ├── Info.toml              # Mandatory TOML manifest
    ├── Manifest.sha256        # Optional (recommended) SHA-256 integrity manifest
    ├── Manifest.sig           # Optional detached cryptographic signature over Manifest.sha256
    ├── MacOS/                 # Entry executables
    │   ├── example            # Arch-independent or single-arch entry
    │   ├── x86_64/example     # Universal bundle binary (x86_64)
    │   └── aarch64/example    # Universal bundle binary (aarch64)
    ├── Frameworks/            # Bundled shared libraries (.so*) — added to LD_LIBRARY_PATH
    │   ├── x86_64/            # Optional arch-scoped libraries
    │   └── aarch64/
    ├── Resources/             # Icons (icon.svg / icon.png), assets, translations
    ├── WinePrefix/            # (runtime = "wine") Complete self-contained WINEPREFIX + .exe
    └── PlugIns/               # Optional plugins (e.g., PlugIns/qt6)
```
*(v1 bundles using `Contents/Executable/` and `Contents/Libraries/` remain accepted.)*

### 2.1 `Contents/Info.toml` Schema

Required keys:
| Key | Type | Description |
|---|---|---|
| `bundle_format` | String | `"conjunction.app/2"` (or `"conjunction.app/1"`). |
| `id` | String | Reverse-DNS identifier (e.g. `"org.example.notes"`), `>= 2` segments `[a-zA-Z0-9_-]`. |
| `name` | String | Human-readable display name (UTF-8). |
| `version` | String | Application version string. |
| `executable` | String | Relative path inside bundle (e.g. `"Contents/MacOS/notes"` or `"Contents/MacOS/{arch}/notes"`), optional if `[executables]` table is provided. |
| `architectures` | Array | Non-empty subset of `["x86_64", "aarch64", "noarch"]`. |

Optional keys:
| Key | Type | Description |
|---|---|---|
| `runtime` | String | `"conjunction-1"` (default), `"appimage"`, `"flatpak"`, `"wine"`, or `"static"`. |
| `minimum_os` | String | Minimum Fedora/Conjunction OS version (e.g. `"41"` or `"conjunction-41"`). |
| `icon` | String | Relative path (`"Contents/Resources/icon.svg"`) or theme icon name (`"utilities-terminal"`). |
| `mime_types` | Array | Handled MIME types (e.g. `["text/plain", "text/markdown"]`). |
| `url_schemes` | Array | Custom URL schemes (registered as `x-scheme-handler/<scheme>`). |
| `[[document_types]]` | Array of Tables | Rich document declarations: `name`, `role`, `mime_types`, `extensions`, `icon`. |
| `category` | String | FreeDesktop category (e.g. `"Utility"`, `"Development"`). |
| `description` | String | Summary shown in launchers and inspection tools. |
| `terminal` | Bool | Run inside terminal emulator (`false` by default). |
| `permissions` | Array | Declared capability hints. |
| `[data]` | Table | Optional custom XDG directory namespace overrides (`config`, `cache`, `state`, `data`). |
| `[executables]` | Table | Explicit per-arch paths (`x86_64 = "..."`, `aarch64 = "..."`). |
| `[flatpak]` | Table | Required when `runtime = "flatpak"`: `id`, `scope` (`"user"`/`"system"`), `remote`. |
| `[wine]` | Table | Required when `runtime = "wine"`: `prefix` (default `"Contents/WinePrefix"`), `target_exe`, `args`, `arch`, `esync`, `fsync`, `dxvk_hud`, `wine_debug`, `use_proton`. |
| `[appimage]` | Table | Optional for `runtime = "appimage"`: `payload`, `extract_and_run_fallback` (default `true`). |

### 2.2 Universal Bundles

A universal bundle provides both `x86_64` and `aarch64` executables under `Contents/MacOS/x86_64/<name>` and `Contents/MacOS/aarch64/<name>` (or via `[executables]` / `{arch}` substitution) with `architectures = ["x86_64", "aarch64"]`.
At launch, `conj-open` / `AppRegistry` picks the host architecture (`x86_64` or `aarch64`), falling back to an arch-independent entry only if the bundle declares `"noarch"` or includes the host architecture. If the host architecture binary is absent, launch fails immediately with `UnsupportedHostArchitecture` stating the host architecture and missing path.

---

## 3. Runtime & ABI Contract

### 3.1 `conjunction-1` Base Runtime ABI

Bundles declaring `runtime = "conjunction-1"` (the default) may dynamically link only against the base libraries guaranteed by the Conjunction Fedora Atomic KDE Plasma 6 image:
* Linux kernel ABI (`x86_64-v2` / `ARMv8-A aarch64`)
* `glibc` >= 2.39, `libstdc++` (GCC 14+ ABI), `libgcc_s`, `zlib`, `openssl` (3.x)
* Display & input: `libwayland-client`, `libwayland-egl`, `libxkbcommon`, XWayland compatibility libraries
* Graphics & compute: Mesa `libGL`, `libEGL`, `libgbm`, `libvulkan`
* Audio & IPC: `libpipewire-0.3`, PulseAudio compat socket, `libdbus-1`
* Desktop toolkits: Qt 6 (`Qt6Core`, `Qt6Gui`, `Qt6Widgets`, `Qt6Quick`), GTK 3/4, `xdg-desktop-portal`

Any library outside this base ABI **must** be shipped inside `Contents/Frameworks/` (or `Contents/Frameworks/<arch>/`). On launch, the launcher validates containment and prepends existing framework directories to `LD_LIBRARY_PATH` (and `Contents/PlugIns/qt6` to `QT_PLUGIN_PATH`).

### 3.2 Wrapped Formats (Day-One App Ecosystem)

1. **AppImage (`runtime = "appimage"`)**:
   * Created via `conj-bundle wrap-appimage <file.AppImage> <Out.app> --id ... --name ...`.
   * Payload lives in `Contents/MacOS/<name>.AppImage`.
   * If `/dev/fuse` is inaccessible (e.g., containers), the launcher sets `APPIMAGE_EXTRACT_AND_RUN=1` automatically.
2. **Flatpak (`runtime = "flatpak"`)**:
   * Created via `conj-bundle wrap-flatpak <flatpak-id> <Out.app>`.
   * Thin launcher invoking `flatpak run <--user|--system> <flatpak_id>`.
   * Deleting `<Name>.app` causes `conj-appd` to trigger `flatpak uninstall` for that Flatpak ID (provided no other `.app` bundle still references it). Standalone Flatpaks without a `.app` wrapper are never touched.
3. **Windows Apps (`runtime = "wine"`)**:
   * Created via `conj-bundle wrap-exe`, `cj install <app.exe|.msi>`, or `engine.py` `ConjunctionAPI.install_bundle()`.
   * Both the `.exe` and its complete Wine prefix live inside `Contents/WinePrefix/` (using relative paths). Deleting the `.app` removes the entire Windows installation.
   * When launched from a read-only `.cdmg` mount, `conj-open` shadows `Contents/WinePrefix/` into `~/.cache/conjunction/ro-wine/<id>-<hash>/` so the app still runs cleanly.

---

## 4. Discovery & XDG Integration (`conj-appd`)

* **Watched directories**:
  * System-wide: `/Applications` (symlinked to `/var/Applications` on the atomic rootfs)
  * Per-user: `~/Applications` (`$HOME/Applications`)
* **Real-time watching**: `conj-appd` uses Linux `inotify` (`IN_CREATE`, `IN_DELETE`, `IN_MOVED_TO`, `IN_MOVED_FROM`, `IN_CLOSE_WRITE`, `IN_ATTRIB`, `IN_DELETE_SELF`, `IN_MOVE_SELF`) on both directories and immediate `*.app`/`Contents/` subdirectories with a ~150ms coalescing debounce (and quick retry if a directory copy is mid-flight).
* **Generated XDG Data Dir**: `$XDG_DATA_HOME/conjunction/xdg` (default `~/.local/share/conjunction/xdg`):
  * `applications/conj-<id>.desktop` (`Exec=conj-open --bundle "<bundle_path>" %U`, `MimeType=` including `url_schemes` `x-scheme-handler/<scheme>` and `[[document_types]]`)
  * `icons/hicolor/{scalable,256x256}/apps/conj-<id>.{svg,png}` + `index.theme`
  * `mime/packages/conj-<id>.xml` (for custom `[[document_types]]` extensions)
  * `applications/mimeapps.list` (regenerated from active bundles)
  * Refreshes `update-desktop-database`, `update-mime-database`, and `kbuildsycoca6` when generated entries change.
* **No Stale Registry Database**: `conj-appd` rebuilds active state strictly from `.app` bundles on disk at startup and on every reconcile, purging any orphaned `conj-*.desktop`, `conj-*.xml`, `conj-*.*` icon, or `mimeapps.list` entries left over from offline deletions.

---

## 5. Leftover Data Tracking

Known per-bundle-id directories (not inside the `.app` itself):
* `$XDG_CONFIG_HOME/<id>` (`~/.config/<id>`)
* `$XDG_DATA_HOME/<id>` (`~/.local/share/<id>`)
* `$XDG_CACHE_HOME/<id>` (`~/.cache/<id>`)
* `$XDG_STATE_HOME/<id>` (`~/.local/state/<id>`)
* `$HOME/.var/app/<flatpak_id>` (for Flatpak-backed bundles)
*(Overridable per domain via `[data]` in `Info.toml`.)*

When a bundle disappears, `conj-appd` records any existing paths above into `$XDG_STATE_HOME/conjunction/leftovers/<id>.json` with byte sizes. Settings (`conj-appctl leftovers list` / `conj-appctl leftovers purge <id>`) can offer "Remove leftover data" later. Protected user directories (`~/Documents`, `~/Desktop`, `~/Downloads`, `~/Pictures`, `~/Music`, `~/Videos`) and symlinks escaping `$HOME` are never touched.

---

## 6. Disk Images (`.cdmg`)

* **Extension**: `.cdmg` (`application/x-conjunction-disk-image`)
* **Filesystem**: SquashFS (`mksquashfs -comp zstd`, magic `hsqs`) by default; EROFS (`mkfs.erofs`, magic `0xe0f5e1e2` at offset 1024) optional via `--fs erofs`.
* **Contents**:
  * `<Name>.app/` (validated & optionally sealed/signed)
  * `Applications -> /Applications` symlink
  * `.VolumeMeta.toml` (volume name, layout geometry, `app_bundle`, `app_id`)
  * Optional `.background/<image>` and `.VolumeIcon.{svg,png}` / `.directory`
* **CLI & Double-Click Lifecycle**:
  * Pack: `conj-bundle pack MyApp.app MyApp.cdmg [--fs squashfs|erofs]`
  * Double-click / Mount: `conj-open MyApp.cdmg` mounts read-only unprivileged under `$XDG_RUNTIME_DIR/conjunction/mounts/<vol>-<hash8>` via `squashfuse` / `erofsfuse` (zero polkit prompt) or `udisksctl` (`udisks2`), then opens the mount in Dolphin / Conjunction Files.
  * Direct Run: Double-clicking `MyApp.app` inside the mounted `.cdmg` executes directly from the read-only image.
  * Drag to Install: Copy `MyApp.app` out to `~/Applications` or `/Applications` (`Applications` symlink).
  * Eject: `conj-bundle eject <target>` or `conj-open --eject <target>` (or context menu "Eject Disk Image").

---

## 7. Security Model

1. **No code execution on install/discovery**: `conj-appd`, `conj-bundle`, and `AppRegistry` only parse `Info.toml` and `Manifest.sha256`.
2. **Containment & traversal rejection**: Absolute paths, `..` components, NUL bytes, non-regular or non-executable targets, and any symlink inside `Contents/` (including `MacOS/`, `Frameworks/`, `Resources/`, `WinePrefix/`) resolving outside the canonical bundle root are rejected unconditionally.
3. **Integrity manifest & signature**: `conj-bundle seal` writes deterministic `Contents/Manifest.sha256` covering all files/symlinks in `Contents/` (and rejects tampered or injected unexpected files during `validate`/`verify`). `--key <priv.pem>` produces `Contents/Manifest.sig` using OpenSSL `pkeyutl` (verified with `--pubkey <pub.pem>`).
4. **Quarantine xattrs**: `conj-bundle quarantine <path> [--url <origin>]` sets `user.conjunction.quarantine` and `user.xdg.origin.url`. `conj-open` refuses to silently open quarantined bundles/images in non-interactive runs unless `--allow-quarantined` is passed, and prompts interactively (clearing quarantine after explicit user approval).

---

## 8. Dolphin & File Manager Integration (and Limits)

* **Implemented**:
  * `data/mime/packages/conjunction-bundles.xml`: registers `application/x-conjunction-app` (`*.app`, subclass of `inode/directory`) and `application/x-conjunction-disk-image` (`*.cdmg`).
  * `data/applications/conjunction-cdmg.desktop` & `conjunction-open.desktop`: handles double-click on `.cdmg` files in Dolphin (and `.app` in `conjunction-files` / `xdg-open`).
  * `data/dolphin-plugin/`: native KF6 `KAbstractFileItemActionPlugin` (`conjunction_app_action`) adding **"Open Application"** and **"Show Package Contents"** strictly on valid `*.app` directories (plus Mount/Eject for `.cdmg`), and `KIO::ThumbnailCreator` (`conjunction_app_thumbnailer`) rendering `.app` bundle icons without writing files into read-only mounts.
  * `data/kio/servicemenus/conjunction-app.desktop`: KIO service menu fallback.
* **Honest Limits**:
  * Upstream KDE Dolphin's `DolphinView::slotItemActivated` checks `KFileItem::isDir()` on double-click and unconditionally navigates into directories instead of dispatching through MIME handlers. Without patching Dolphin itself (or using Conjunction's own `conjunction-files`), double-clicking a `.app` directory in unpatched Dolphin enters the folder; users launch `.app` folders in stock Dolphin via right-click → **Open Application**, or directly from KDE Application Launcher / Dock / KRunner.

---

## 9. Image Integration (for Fedora Atomic / `bootc` Containerfile)

Install the following artifacts produced/owned by this subsystem into the Fedora Atomic KDE Plasma 6 OCI image:

| Artifact | Target Path in Image | Purpose |
|---|---|---|
| Rust binaries (`cargo build --release --workspace`) | `/usr/bin/conj-appd`, `/usr/bin/conj-appctl`, `/usr/bin/conj-bundle`, `/usr/bin/conj-open`, `/usr/bin/cj`, `/usr/bin/application` | Core bundle daemon, opener, packer, CLI |
| Python Wine runner | `/usr/lib/conjunction/engine.py`, `/usr/lib/conjunction/cli.py` | Self-contained Wine `.app` installer/runner |
| Default Terminal bundle | `/var/Applications/Terminal.app` (or `/usr/share/conjunction/Terminal.app` copied on first boot) | Built-in Terminal `.app` |
| Systemd user service | `/usr/lib/systemd/user/conj-appd.service` (from `data/systemd/user/conj-appd.service`) + enable in `conjunction-session.target.wants` | Auto-starts `conj-appd` per user session |
| System `/Applications` directory | Rootfs symlink `ln -s var/Applications /Applications` + `/usr/lib/tmpfiles.d/conjunction-apps.conf` (from `data/tmpfiles.d/conjunction-apps.conf`) | Writable `/Applications` on atomic `/usr`-RO image |
| Generated XDG env | `/usr/lib/environment.d/60-conjunction-apps.conf` (from `data/environment.d/60-conjunction-apps.conf`) and `/etc/xdg/plasma-workspace/env/conjunction-apps.sh` (from `data/plasma-env/conjunction-apps.sh`) | Exposes `~/.local/share/conjunction/xdg` to Plasma/KRunner/Dolphin |
| MIME & desktop handlers | `/usr/share/mime/packages/conjunction-bundles.xml`, `/usr/share/applications/conjunction-open.desktop`, `/usr/share/applications/conjunction-cdmg.desktop` + run `update-mime-database /usr/share/mime` & `update-desktop-database /usr/share/applications` | Registers `.app` and `.cdmg` MIME types |
| Dolphin/KIO integration | Build `data/dolphin-plugin` via CMake against `kf6-kio-devel`, `extra-cmake-modules`, `qt6-qtbase-devel` -> installs into `/usr/lib64/qt6/plugins/kf6/{kfileitemaction,thumbcreator}/`; install `data/kio/servicemenus/conjunction-app.desktop` (`0755`) to `/usr/share/kio/servicemenus/` | Dolphin context menu & bundle icon previews |
| Optional polkit rule | `/etc/polkit-1/rules.d/50-conjunction-cdmg.rules` (from `data/polkit-1/rules.d/50-conjunction-cdmg.rules`) | Allows `wheel` users `udisks2` loop-mount without prompt |
| Required OS packages | `squashfs-tools`, `squashfuse`, `fuse3`, `desktop-file-utils`, `shared-mime-info`, `openssl`, `wine` (x86_64) | `.cdmg` pack/mount, XDG caches, signatures, Wine |
