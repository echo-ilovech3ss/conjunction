# Conjunction OS Roadmap

## Phase 1: Fedora Atomic (`bootc`) Base & Packaging (Current)

- [x] Rebase OS image from Arch/`archiso`/Calamares onto multi-arch `quay.io/fedora/fedora-kinoite:45` (`bootc`).
- [x] Multi-stage `os/Containerfile` building all Rust workspace binaries (`conj-appd`, `conj-open`, `conj-bundle`, `conj-appctl`, `conj-sysd`, `cj`, `application`, `app_sync`), C++/Qt6/KF6 components (`conj-shelld`, `conj-notificationd`, `conjunction-files`, `conjunction-settings`, `conjunction-terminal`, `conjunction-design`), and the Dolphin KF6 plugin.
- [x] Dedicated `x86_64` NVIDIA image variant (`os/Containerfile.nvidia`) with `akmod-nvidia` and kernel arguments (`os/nvidia/usr/lib/bootc/kargs.d/05-nvidia.toml`).
- [x] Declarative installable media (`anaconda-iso` with Btrfs rootfs) via `bootc-image-builder` and `os/iso-config.toml`.
- [x] Typography (`Inter`, `Inter Display`, `JetBrains Mono`, `Material Symbols Rounded`) and `MacTahoe` icon/GTK themes with documented licensing and non-trademark icon overrides (`os/ASSETS-LICENSES.md`).
- [x] Out-of-the-box Flathub, Distrobox, RPM Fusion codecs, firmware, Wine/DXVK/`umu-launcher` (`x86_64`), and FEX-Emu/Box64 (`aarch64`).
- [x] Multi-arch GitHub Actions CI/CD building `linux/amd64` + `linux/arm64` images, pushing GHCR multi-arch manifests on `main`, and producing `workflow_dispatch` installer ISOs.

## Phase 2: Application Bundles & Compatibility

- [x] `conjunction.app/2` directory bundles in `/Applications` (`-> /var/Applications`) and `~/Applications` with `inotify`-driven `conj-appd` XDG synchronization.
- [x] `.cdmg` SquashFS/EROFS disk images with unprivileged `squashfuse`/`erofsfuse` and Polkit/udisks2 mounting.
- [ ] Seamless `x86_64` Wine/Proton `.app` integration inside `aarch64` via automated FEX rootfs / Box64 Wine runner wiring.
- [ ] First-boot Flatpak/Flathub pre-seeding and Store UI integration in `conjunction-settings`.

## Phase 3: Desktop Shell & KWin Experience

- [ ] Complete `conj-shelld` top menu bar / dock / global menu DBus integration over KWin Wayland.
- [ ] Polish `conjunction-overview` KWin Mission Control effect and Conjunction Plasma Look-and-Feel defaults.
- [ ] Complete hardware bring-up validation across real UEFI `x86_64` (Intel/AMD/NVIDIA) and Apple Silicon / `aarch64` targets.
