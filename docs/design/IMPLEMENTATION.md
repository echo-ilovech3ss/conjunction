# Conjunction Desktop Implementation Map

This document maps `docs/design/SPEC.md` to the clean-room implementation across the Conjunction workspace, summarizes verification coverage on Fedora 45, and notes known environment gaps.

## 1. Specification-to-Implementation Map

| SPEC Section | Component / Feature | Implementation Files |
|---|---|---|
| **§1 Liquid Glass Material System** | Qt6 GLSL shaders (`squircle_shape`, `glass_blur`, `liquid_glass`, `morph_glass`), QML `GlassSurface` / `GlassMorphContainer` / `ScrollPocket`, KWin `KWin::OffscreenEffect` plugin | `conjunction-design/shaders/{squircle_shape.vert,squircle_shape.frag,glass_blur.vert,glass_blur_h.frag,glass_blur_v.frag,liquid_glass.vert,liquid_glass.frag,morph_glass.vert,morph_glass.frag}`, `conjunction-design/qml/Conjunction/Design/{GlassSurface.qml,GlassMorphContainer.qml,ScrollPocket.qml,SquircleRect.qml,Surface.qml}`, `kwin/effects/liquidglass/{liquidglass_effect.cpp,liquidglass_effect.h}` |
| **§1.5 Accessibility Material Fallbacks** | Live Reduce Transparency & Increase Contrast switching | `conjunction-design/qml/Conjunction/Design/{Appearance.qml,Theme.qml}`, `conj-shelld/src/{shell_state.cpp,shell_state.h}`, `conjunction-settings/qml/pages/AppearancePage.qml` |
| **§2 Design Tokens & Controls** | Radii, concentric nesting, spacing grid, `Conjunction.Controls` primitives, keyboard focus ring, fontconfig aliases, Material + Phosphor icons | `conjunction-design/qml/Conjunction/Design/{Geometry.qml,Spacing.qml,Theme.qml,Typography.qml,FocusModel.qml,FocusRing.qml,Icon.qml,Icons.qml}`, `conjunction-design/qml/Conjunction/Controls/*.qml`, `data/fontconfig/99-conjunction-fonts.conf`, `data/icons/phosphor/*.svg` |
| **§2.9 Wallpapers & Branding** | Procedural light/dark wallpapers and Conjunction emblem | `data/wallpapers/conjunction-{light,dark}.svg`, `conj-shelld/qml/assets/conjunction-mark.svg` |
| **§3 Motion System** | Spring/duration tokens, cosine-bell Dock magnification ($w(d) = 0.5(1 + \cos(\pi d / R))$, $R = 3 P_0$), KWin window motion & Genie/Scale minimize effect, Reduced Motion crossfade | `conjunction-design/qml/Conjunction/Design/Motion.qml`, `kwin/effects/motion/{motion_effect.cpp,motion_effect.h}`, `conj-shelld/qml/Dock.qml`, `plasma/kwinrc` |
| **§4.1 Menu Bar (Top Shell Panel)** | Top bar, system mark menu, active app title, global AppMenu D-Bus bridge, right status tray, responsive clipping/elision | `conj-shelld/qml/TopBar.qml`, `conj-shelld/src/{menu_registrar.cpp,menu_registrar.h}` |
| **§4.2 Dock** | Floating Clear Glass capsule, adaptive `baseTileSize`, cosine-bell hover magnification, active indicator dots, minimized window thumbnails, Trash slot | `conj-shelld/qml/Dock.qml`, `conj-shelld/src/{shell_state.cpp,shell_state.h,window_manager.cpp,window_manager.h}` |
| **§4.3–4.4 Control Center & Notifications** | Modular Control Center capsules, Notification Center calendar/system widgets & stack, notification daemon D-Bus queue, Overview / Mission Control & Quick Note overlays | `conj-shelld/qml/{ShellWindow.qml,ControlCenter.qml,NotificationCenter.qml,NotificationBanner.qml,OverviewOverlay.qml,QuickNoteOverlay.qml}`, `conj-notificationd/src/{main.cpp,notification_manager.cpp,notification_manager.h}` |
| **§4.5 Quick Search & App Launcher** | Two-pane Spotlight search + preview inspector, full App Launcher grid, App Switcher HUD (`Cmd/Meta+Tab`) | `conj-shelld/qml/{Spotlight.qml,AppLauncher.qml,AppSwitcherHUD.qml}` |
| **§4.6 Window Chrome & Traffic Lights** | `KDecoration3` Glass decoration plugin (`org.conjunction.glass`), cluster button hover glyphs, shadows, Plasma defaults | `kwin/decoration/{glassdecoration.cpp,glassdecoration.h,glassdecoration.json}`, `conj-shelld/qml/TrafficLights.qml`, `plasma/{kdeglobals,kwinrc,look-and-feel/org.conjunction.desktop/contents/defaults}` |
| **§4.7 Files Application** | Sidebar favorites/volumes, unified toolbar, Icon / List / Column / Gallery views, Quick Look preview, Get Info modal, Confirm Delete | `conjunction-files/qml/{FilesWindow.qml,FilesSidebar.qml,FilesToolbar.qml,FilesIconView.qml,FilesListView.qml,FilesColumnView.qml,FilesGalleryView.qml,QuickLookOverlay.qml,GetInfoDialog.qml,ConfirmDeleteDialog.qml}`, `conjunction-files/src/{main.cpp,files_model.cpp,column_model.cpp,sidebar_model.cpp,file_item.cpp,file_operations.cpp,quicklook_service.cpp}` |
| **§4.8 System Settings** | Searchable sidebar and 10 settings panes (`about`, `appearance`, `default-apps`, `shortcuts`, `dock`, `displays`, `sound`, `network`, `bluetooth`, `search`) | `conjunction-settings/qml/{SettingsWindow.qml,SettingsSidebar.qml}`, `conjunction-settings/qml/pages/*.qml`, `conjunction-settings/src/{main.cpp,settings_manager.cpp,system_info.cpp,audio_backend.cpp,bluetooth_backend.cpp,display_backend.cpp,network_backend.cpp}` |
| **Terminal & Core Libraries** | KonsolePart host with dark/light ThemeBridge, shell-safe argument escaping, find bar, Rust workspace libraries & adapters | `conjunction-terminal/src/{main.cpp,terminal_window.cpp,terminal_session.cpp,terminal_find_bar.cpp,theme_bridge.cpp,shell_escape.cpp}`, `conjunction-core/src/*.rs` |
| **Overflow Audit & Gallery** | Shared QML scene-tree overflow & truncation checker (`Conjunction::OverflowAudit`), 27-scene Design Gallery & Stress scene | `conjunction-design/common/overflow_audit.h`, `conjunction-design/gallery/{Main.qml,main.cpp,scenes/*.qml,deterministic/DeterministicScene.qml}` |

## 2. Clean-Room Assets & Typography Pipeline

- Fonts & symbol mapping: `data/fontconfig/99-conjunction-fonts.conf` aliases `Material Symbols Rounded` to `Material Icons Round` / `Material Icons`. For newer ligatures absent from legacy `MaterialIconsRound-Regular.otf` (`terminal`, `sun`, `moon`, `focus`, `nearby`, `stage`, `settings`, `preferences-system`, `utilities-terminal`) and in `conj-shelld`'s `ThemeIconProvider`, `Icon.qml` / `Icons.qml` route directly to bundled Phosphor SVGs (`/usr/share/conjunction/icons/phosphor/*.svg`) or painted fallback glyphs.
- `.app` v1 bundles: `conjunction-files/src/file_item.cpp` and `data/Terminal.app/Contents/Info.toml` use the spec-mandated `Contents/MacOS/` executable convention with zero proprietary branding, fonts, or system bundles imported.

## 3. Automated UI Overflow Hardening & Stress Verification

All QML controls, gallery scenes (27 scenes), `conj-shelld` composite overlays, `conjunction-files` (all 4 view modes + Quick Look + Get Info), and `conjunction-settings` (all 10 pages) are audited via `Conjunction::OverflowAudit::auditWindow` (`--audit-overflow` / `--stress-mode`), checking for:

- `text_truncated_no_elide` / `text_width_overflow` / `text_height_overflow`
- `window_bounds_overflow` / `clipped_by_ancestor` outside `Flickable` scroll viewports
- `sibling_overlap` inside `Row` / `RowLayout` / `Column` / `ColumnLayout`

Evidence screenshots are stored under `out/shell-evidence/{design,kwin,motion,shell,apps,overflow}/`.

## 4. Known Gaps (`SPEC-GAP`) & Verification Limits

`rg -n "SPEC-GAP"` across the codebase returns `0` inline annotations; observed environment/verification boundaries are:

- **Headless XCB Verification (`Xvfb` / Mesa `llvmpipe`) vs. Live Wayland Compositor**: Functional, overflow, and screenshot verification in the Fedora 45 container (`conj-f45-verify`) ran under `Xvfb :98` with `QT_QPA_PLATFORM=xcb` and software OpenGL. KWin 6 plugins (`org.conjunction.glass.so`, `conjunctionglass.so`, `conjunctionmotion.so`) compiled and installed cleanly in the container, while live KWin Wayland compositor runtime effects, multi-touch `libinput` gestures, and UDisks2 real block-device `.cdmg` mounts require a full desktop/VM Wayland session.
- **Settings Hardware Backends in Minimal Container**: `NetworkBackend`, `BluetoothBackend`, `AudioBackend`, and `DisplayBackend` gracefully degrade to default/fallback state when system hardware daemons (`NetworkManager`, `BlueZ`, `PipeWire`) are not active inside the verification container.
