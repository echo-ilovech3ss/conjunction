# Conjunction OS

Conjunction is a desktop operating system built as a multi-arch (`x86_64` / `aarch64`) **Fedora Atomic (`bootc`) KDE Plasma 6** OCI image (`quay.io/fedora/fedora-kinoite:45`) with custom Rust and C++/Qt6/KF6 components, `.app` bundle & `.cdmg` disk image support, and installable media generated via `bootc-image-builder`.

## Architecture Overview

| Layer | Technology | Location |
|---|---|---|
| Base OS | Fedora 45 Kinoite (`bootc`, ostree + composefs, Plasma 6 / KWin Wayland) | [`os/Containerfile`](os/Containerfile) |
| NVIDIA Variant | `x86_64` RPM Fusion NVIDIA driver + `nouveau` blacklist kargs | [`os/Containerfile.nvidia`](os/Containerfile.nvidia) |
| Installer Media | Anaconda (`anaconda-iso`) generated via `bootc-image-builder` | [`os/iso-config.toml`](os/iso-config.toml) |
| Rust Daemons & CLI | `conj-appd`, `conj-open`, `conj-bundle`, `conj-appctl`, `conj-sysd`, `cj`, `application`, `app_sync` | Workspace crates |
| Desktop UI (C++/Qt6/KF6) | `conj-shelld`, `conj-notificationd`, `conjunction-files`, `conjunction-settings`, `conjunction-terminal`, `conjunction-design`, KWin glass/motion (`kwin/`), Plasma look-and-feel (`plasma/`), Dolphin KF6 plugin | C++/QML directories & `data/dolphin-plugin/` |
| Typography & Themes | `Inter` + `Inter Display` (`OFL-1.1`), `JetBrains Mono` (`OFL-1.1`), `Material Symbols Rounded` (`Apache-2.0`), `MacTahoe` icon (`GPL-3.0`) & GTK (`MIT`) themes, Phosphor icons (`MIT`) | [`os/ASSETS-LICENSES.md`](os/ASSETS-LICENSES.md) |
| Software Ecosystem | Flathub, Distrobox, RPM Fusion codecs, Wine/DXVK/`winetricks` (`x86_64`; `umu-launcher` skipped when absent in F45), FEX-Emu + `fex-emu-rootfs-fedora` + Box64 + x86_64 Wine-Proton WoW64 (`aarch64`) | [`os/Containerfile`](os/Containerfile) |

> **Architecture Note (`aarch64`)**: Native `wine` and `umu-launcher` are not packaged in Fedora 45 / `bazzite-org/bazzite` for `aarch64` (and `bazzite-org/bazzite` currently has no `fedora-45` chroot on `x86_64` either). On `aarch64`, Conjunction ships Fedora's `fex-emu` (`2604`), `fex-emu-rootfs-fedora`, `fex-emu-thunks`, `box64`, `winetricks`, and a bundled `x86_64` Wine-Proton WoW64 runtime wrapped through `FEXInterpreter` with `binfmt_misc` active.

## Quickstart (Rootful Podman + `bootc-image-builder`)

### 1. Build the OCI Image

On Linux or inside a rootful Podman VM (`podman machine init --cpus 6 --memory 8192 --disk-size 120 --rootful`):

```bash
# Native host architecture (e.g. linux/arm64 on Apple Silicon, linux/amd64 on x86_64)
podman build --ignorefile os/.containerignore -f os/Containerfile -t localhost/conjunction:45-arm64 --platform linux/arm64 .

# x86_64 + optional NVIDIA variant
podman build --ignorefile os/.containerignore -f os/Containerfile -t localhost/conjunction:45-amd64 --platform linux/amd64 .
podman build --ignorefile os/.containerignore -f os/Containerfile.nvidia --build-arg BASE_IMAGE=localhost/conjunction:45-amd64 -t localhost/conjunction:45-nvidia-amd64 --platform linux/amd64 .
```

### 2. Verify Image Health

```bash
podman run --rm localhost/conjunction:45-arm64 bootc container lint --fatal-warnings
```

### 3. Generate Installable ISO (`anaconda-iso`)

```bash
mkdir -p out/iso-arm64
# bootc-image-builder's legacy anaconda-iso repo lookup keys on os-release ID=conjunction,
# so pass --force-repo pointing to the matching Fedora 45 Everything tree.
podman run --rm --privileged \
  -v "$(pwd)/os/iso-config.toml:/config.toml:ro" \
  -v "$(pwd)/out/iso-arm64:/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  build \
  --type anaconda-iso \
  --rootfs btrfs \
  --force-repo "https://dl.fedoraproject.org/pub/fedora/linux/releases/45/Everything/aarch64/os/" \
  localhost/conjunction:45-arm64
```

The installable ISO is written to `out/iso-arm64/bootiso/install.iso`.

### 4. Rebasing an Existing `bootc` Installation

```bash
sudo bootc switch ghcr.io/echo-ilovech3ss/conjunction:latest
# Or for x86_64 NVIDIA systems:
sudo bootc switch ghcr.io/echo-ilovech3ss/conjunction:nvidia
```

## Development Checks

```bash
cargo test --workspace --locked
python3 -m pytest -q
git ls-files -z '*.sh' | xargs -0 -r -n1 bash -n
```

See [`docs/APP_BUNDLES.md`](docs/APP_BUNDLES.md) for the `.app` bundle and `.cdmg` disk image specification, and [`ROADMAP.md`](ROADMAP.md) for current milestones.
