# Conjunction Distro Roadmap

Conjunction is an Arch-based Linux distribution focused on four things:

- macOS-like simplicity: clean live desktop, application launcher, top bar, dock, sane defaults.
- Linux control: pacman/Flatpak access, Btrfs snapshots, normal filesystem layout, no locked-down appliance behavior.
- Windows app compatibility: Wine/Proton prefixes managed through `cj`, not exposed to normal users.
- Reliable installability: Hyper-V, QEMU, USB boot, UEFI, and BIOS must work before visual polish expands.

## Phase 1: Bootable Installer Baseline

- Live ISO autologins as the `conjunction` user through SDDM.
- X11 is the default live desktop session for better VM and Hyper-V compatibility.
- Installer supports `/dev/sda`, `/dev/vda`, `/dev/nvme0n1`, and other partition naming schemes.
- Installer auto-detects UEFI versus BIOS and defaults to the correct partitioning path.
- Installed services must match installed packages. No service should be enabled unless its package is installed.
- First-boot post-install tasks must be one-shot or clearly named recurring tuning services.

## Phase 2: Product-Grade Install UX

- Replace the destructive shell installer with Calamares or a small TUI/GUI wrapper around proven Arch install primitives.
- Add explicit install modes: erase disk, manual partitioning, VM-safe install.
- Add preflight checks for network, disk size, UEFI, secure boot, and mirror availability.
- Write install logs to `/var/log/conjunction-installer.log` and show exact failure reasons.

## Phase 3: Conjunction Desktop Identity

- Move KDE defaults into `/etc/skel` and system-level Plasma config where possible.
- Provide an Applications folder launcher experience using KDE favorites/categories and Dolphin shortcuts.
- Ship a small Conjunction welcome app for install, Windows app setup, updates, and docs.
- Keep macOS inspiration as UX direction, not a clone. The name shown to users should be `Conjunction`.

## Phase 4: Windows Compatibility Layer

- Make `cj install path/to/app.exe` create one isolated prefix per app.
- Prefer Wine-GE/Proton-GE when available, fallback to system Wine.
- Add DXVK/VKD3D setup validation and clear errors when Vulkan is missing.
- Add per-app launch profiles for GPU, audio, debug logs, and safe-mode launch.
- Treat Adobe-class apps as stretch targets; start with smaller installers, then games, then productivity suites.

## Phase 5: Release Discipline

- Add automated ISO build verification in a Linux builder.
- Smoke-test in QEMU and Hyper-V before considering an ISO usable.
- Version ISOs as `conjunction-YYYYMMDD-x86_64.iso` until semantic releases exist.
- Maintain a known-issues file for unsupported GPUs, secure boot, NVIDIA quirks, and Wine compatibility gaps.

- [x] Migrate Python daemons to Rust for minimal memory footprint
- [x] Fix UEFI boot partition missing packages