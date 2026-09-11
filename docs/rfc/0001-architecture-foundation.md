# RFC 0001: Conjunction OS Architecture Foundation

* **Status**: Accepted
* **Date**: 2026-09-11
* **Scope**: Phase 0 — Core Architecture & System Contracts

---

## 1. Executive Summary

Conjunction is a compatibility-oriented desktop operating system built on Arch Linux. Its mission is to deliver the application-centric simplicity, predictability, and keyboard/mouse fluency of macOS, paired with deep Windows compatibility and the open, customizable foundation of Linux.

Rather than attempting to rewrite the entire operating system stack, Conjunction establishes a cohesive **Application Services** layer above standard Linux subsystems. This layer treats every application as a first-class `.app` bundle while preserving upstream Arch, pacman, systemd, Wayland, and XDG standards underneath.

---

## 2. Project Goals & Explicit Non-Goals

### Goals
1. **Application-Centric Interaction**: Applications are first-class, single-object entities (`Application.app`) across file managers, launchers, dock, and settings.
2. **Clear Data Lifecycle**: Standardized separation between executable bundles and mutable user state, providing clean removal ("Delete App" vs. "Delete App and Data").
3. **Broad Software Compatibility**: Multi-tiered compatibility ladder spanning native Linux, Flatpak, Wine/Proton recipes, and Windows VM streaming.
4. **Upstream Linux Integrity**: Retain full compatibility with standard Arch Linux packages, pacman, systemd, and XDG desktop specifications without breaking or forking core components.
5. **Restrained, Cohesive UI**: Custom Qt 6 / QML design system prioritizing content over chrome, strict keyboard operability, and predictable hierarchy without copying Apple proprietary trade dress.

### Explicit Non-Goals
1. **Not a Custom Wayland Compositor**: We do not write a compositor from scratch. We leverage KWin.
2. **Not a Package Manager Replacement**: We do not replace pacman or re-invent package distribution. Pacman remains the authoritative base engine.
3. **Not a Clone of macOS UI/Trade Dress**: We do not use Apple fonts (San Francisco), SF Symbols, or proprietary graphics. We build a distinctive Conjunction visual identity.
4. **Not Universal Wine Magic**: We do not promise 100% Wine translation for complex software (e.g. Adobe Creative Cloud). A dedicated VM streaming escape hatch handles incompatible applications.
5. **No Forked Core Services**: We do not fork PipeWire, NetworkManager, systemd, or kernel subsystems.

---

## 3. System Architecture Layers

```text
┌─────────────────────────────────────────────────────────────┐
│                 Conjunction Desktop Shell                   │
│         (Qt 6 / QML: Top Bar, Dock, Launcher, Settings)     │
├─────────────────────────────────────────────────────────────┤
│               Conjunction Application Services              │
│       (conj-appd, conj-appctl, conj-open, conj-bundle)      │
├─────────────────┬──────────────────┬────────────────────────┤
│ Native .app     │ Linux Adapters   │ Windows Compatibility  │
│ Manifest/AppDir │ pacman / Flatpak │ Wine / Proton / KVM VM │
├─────────────────┴──────────────────┴────────────────────────┤
│           Linux Integration & Desktop Standards             │
│        (XDG BaseDir, .desktop synthesis, MIME, Portals)     │
├─────────────────────────────────────────────────────────────┤
│                   Base OS Infrastructure                    │
│        Arch Linux, systemd, KWin (Wayland), PipeWire        │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Upstream Arch Linux Relationship

* **Base Distribution**: Arch Linux provides rolling packages, Linux kernel, toolchains, and hardware enablement.
* **Packaging Authority**: Pacman manages files in `/usr`, `/etc`, and `/var`. Conjunction never directly modifies or deletes pacman-owned system binaries.
* **Service Management**: `systemd` manages user and system daemons, socket activation, and cgroup resource limits.
* **Display Server**: Wayland is the native display protocol; KWin handles window management, fractional scaling, and hardware acceleration.

---

## 5. The Conjunction `.app` Abstraction

To the graphical user, an application is an opaque directory:
```text
Example.app/
└── Contents/
    ├── Info.toml          # Application metadata & manifest
    ├── Executable/        # Native binaries or launch entry point
    │   └── Example
    ├── Resources/         # Assets, translations, UI files
    ├── Libraries/         # Bundled dynamic libraries (if any)
    ├── PlugIns/           # Extensible plugins
    ├── Icons/             # Vector & raster icons (SVG/PNG)
    ├── XDG/               # Generated/source desktop & MIME templates
    └── Sandbox.toml       # Permission & isolation boundaries
```

### Manifest Concept (`Info.toml`)
* **`id`**: Stable reverse-DNS identifier (e.g. `org.mozilla.firefox` or `dev.example.app`).
* **`name`**: Human-readable display name.
* **`version`**: Semantic version string.
* **`executable`**: Relative path to entry point inside `Contents/Executable/`.
* **`architectures`**: Target CPU architectures (e.g. `["x86_64"]`).
* **`icon`**: Path to main app icon relative to bundle root.
* **`mime_types`**: Array of handled MIME types.
* **`permissions`**: Required portal/system access capabilities.
* **`data`**: Application-owned directory namespaces mapped to XDG.

### Opaque Bundle Semantics
* **Double-click / Open**: Executes via `conj-open`.
* **Inspect Package**: Right-click "Show Package Contents" opens the bundle for inspection.
* **Installation**: Moving `Example.app` into `~/Applications` or `/Applications` registers it.
* **Removal**: Moving to Trash unregisters the app. "Empty Trash" deletes the bundle.
* **"Delete App and Data"**: Explicitly prompts and removes both the bundle and associated XDG data.

---

## 6. Application Services (`conj-appd` & Tools)

1. **`conj-appd`**: Background user daemon responsible for:
   * Monitoring application directories (`~/Applications`, `/Applications`, `/usr/share/applications`).
   * Maintaining an in-memory & cached registry of known applications by reverse-DNS ID.
   * Deterministically resolving ID conflicts (user bundle takes precedence over system bundle).
   * Synthesizing freedesktop `.desktop` files and MIME associations in `~/.local/share/applications/conj/`.
2. **`conj-appctl`**: CLI management utility:
   * `conj-appctl list`: Lists all registered applications and their backing engines.
   * `conj-appctl launch <id|bundle>`: Launches the requested app safely.
   * `conj-appctl uninstall <id> [--with-data]`: Uninstalls and cleanly removes state.
3. **`conj-bundle`**: Build, packaging, validation, and inspection tool for `.app` directories.
4. **`conj-open`**: Default opener resolving files, URLs, and bundle paths to appropriate applications.

---

## 7. Package-Manager Relationship & Linux Adapters

Conjunction does not require every Linux tool to be re-packaged:
* **Thin Adapters**: When a pacman package (e.g., `firefox`) is installed, Conjunction generates a thin adapter bundle representation or integrates its `.desktop` metadata into the registry.
* **Flatpak Integration**: Flatpak applications appear as first-class `.app` objects executing via `flatpak run <id>`.
* **Authoritative Removal**:
  * Deleting a native `.app` deletes the directory.
  * Requesting deletion of a pacman-backed `.app` triggers a transactional pacman removal via polkit.
  * Requesting deletion of a Flatpak `.app` invokes `flatpak uninstall`.
  * Manual deletion of files inside `/usr/bin` is strictly prohibited.

---

## 8. XDG Interoperability & Application Data

Applications map persistent state strictly to standard XDG directories:
* **Configuration**: `$XDG_CONFIG_HOME/<id>` (default `~/.config/<id>`)
* **Cache**: `$XDG_CACHE_HOME/<id>` (default `~/.cache/<id>`)
* **State**: `$XDG_STATE_HOME/<id>` (default `~/.local/state/<id>`)
* **Application Data**: `$XDG_DATA_HOME/<id>` (default `~/.local/share/<id>`)

Standard Linux applications continue functioning normally. Conjunction tracks these paths via the manifest `[data]` block, enabling complete data purges on request while leaving user documents in `~/Documents` untouched.

---

## 9. GUI Stack & Design System

* **Window Manager / Compositor**: KWin under Wayland provides mature display scaling, multi-monitor management, and hardware rendering.
* **UI Framework**: Qt 6 and QML are used for all Conjunction-owned surfaces (Top Bar, Dock, Launcher, Settings, File Manager).
* **Styling**: Fully custom Qt Quick Controls style. No brittle Plasma theme overrides.
* **Design Principles**:
  * Content > Chrome: minimal clutter, clear hierarchy.
  * Full keyboard accessibility: every action accessible via keyboard shortcuts.
  * Progressive disclosure: simple defaults, details exposed contextually.
  * Independent visual identity: no proprietary Apple fonts or trade dress.

---

## 10. Privilege Boundaries & Security Model

* **No Setuid Helpers**: Ad-hoc setuid binaries are prohibited.
* **Polkit for System Operations**: Package management (pacman) and system configuration actions authenticate via standard polkit policies.
* **Direct Execution**: All process launches execute via argument vectors (`execve`), never shell command string concatenation.
* **Defensive Manifest Parsing**: Bundle validation strictly rejects path traversal (e.g., `../../bin/sh`), invalid IDs, and symlink escapes.
* **Sandboxing Direction**: Integrate with `xdg-desktop-portal` and `bubblewrap` (bwrap) / systemd scopes for isolated execution.

---

## 11. Windows Compatibility Ladder

Conjunction approaches Windows compatibility through a pragmatic, tiered hierarchy:

1. **Tier 1 — Wine Direct**: Managed per-application Wine prefix for lightweight Win32/x64 utilities.
2. **Tier 2 — Curated Recipes / Proton**: Bottles-style recipes, runner overrides, DXVK, and VKD3D configuration for complex apps and games.
3. **Tier 3 — Windows VM Streaming (Escape Hatch)**: KVM/QEMU-backed virtual machine streaming individual applications via FreeRDP/WinApps. Used for hostile software like Adobe Creative Cloud or Microsoft 365 without blocking Linux adoption.

---

## 12. Acceptance Gate Verification

| Acceptance Question | Conjunction Specification Answer |
|---|---|
| **What is Conjunction responsible for?** | The `.app` bundle specification, Application Services registry (`conj-appd`), desktop shell, unified file/app UX, design system, and compatibility orchestration. |
| **What remains Arch/upstream responsibility?** | Base OS kernel, systemd init, pacman package database, driver updates, upstream libraries, and KWin Wayland compositor. |
| **What does `.app` mean?** | An opaque, self-contained directory containing `Contents/Info.toml`, binary/entrypoint, resources, and XDG metadata, treated as a single entity. |
| **How will a legacy Linux application participate?** | Discovered via existing freedesktop `.desktop` files and represented as thin `.app` adapters without modifying package files. |
| **Where does privileged code live?** | Behind standard polkit actions and systemd system services; no custom setuid binaries exist in the architecture. |
| **Where will Windows compatibility live?** | In dedicated per-app Wine prefixes, Proton runners, and a fallback KVM VM streaming service (Tier 1-3 compatibility ladder). |
