# Conjunction

An Arch-based Linux distribution prototype focused on macOS-like simplicity, Linux customizability, and strong Windows application compatibility through Wine/Proton.

## Quick Start

### Build the ISO (Windows/macOS/Linux)

**Prerequisites:**
- [Docker Desktop](https://docs.docker.com/desktop/install/) installed and running
- At least 20GB free disk space
- Internet connection

**Build:**
```bash
# Clone or navigate to the project directory
cd conjunction

# Build the ISO
./build-iso.sh

# Build with verbose output
./build-iso.sh --verbose

# Clean build artifacts
./build-iso.sh --clean
```

**Output:**
- ISO file: `./out/conjunction-YYYYMMDD-x86_64.iso`
- Rebuild before testing. The `out/conjunction-profile/` directory is generated and recreated from `archiso/` each build.

### Test in Hyper-V

Recommended VM settings:
- Generation 2 VM
- Secure Boot disabled
- 4GB RAM minimum, 8GB recommended
- 2 CPU cores minimum
- 30GB virtual disk minimum
- ISO attached as DVD boot media

The live image defaults to an X11 Plasma session for better VM compatibility and autologins as the `conjunction` live user.

### Flash to USB

**Windows:**
1. Download [Rufus](https://rufus.ie)
2. Select the ISO file
3. Select your USB drive
4. Click "Start"

**Linux:**
```bash
sudo dd bs=4M if=./out/conjunction-YYYYMMDD-x86_64.iso of=/dev/sdX status=progress
```

**macOS:**
```bash
sudo dd bs=4m if=./out/conjunction-YYYYMMDD-x86_64.iso of=/dev/rdiskN
```

### Installation

1. Boot from USB
2. Click "Install Conjunction OS" on the desktop
3. Follow the installer prompts
4. Reboot and log in
5. Run the UI setup:
   ```bash
   sudo /opt/conjunction/setup_conjunction_ui.sh
   ```
6. Update the system:
   ```bash
   cj update
   ```
7. Optimize performance:
   ```bash
   cj optimize
   ```

## Components

### `setup_conjunction_ui.sh`
Configures KDE Plasma to look and behave like macOS:
- Global menu bar at the top
- Application dock at the bottom
- Window effects (blur, rounded corners, shadows)
- Inter font family
- Breeze Dark theme

### `conjunction-core`
The shared core engine library written in Rust:
- Isolated Wine/Proton prefixes per application inside /Applications/<name>.app/
- Auto-injection of DLLs and codecs
- GPU passthrough (NVIDIA/AMD/Intel)
- Audio mapping (PipeWire/PulseAudio)
- Desktop shortcut synthesis

### `cj`
Simplified system management CLI in Rust:
- `cj update` - Full system update with Btrfs snapshots
- `cj install <app>` - Install native or Windows apps
- `cj optimize` - Performance tuning
- `cj status` - System information
- `cj apps` - Manage installed apps
- `cj setup-wrappers` - Sets up standard utility wrappers

### `application`
Unified package manager command-line utility in Rust:
- `application install <name>` - Installs via flatpak, pacman, or yay, and wraps the package into a /Applications/ container
- `application uninstall <name>` - Cleans up the system packages and removes the container
- `application info <name>` - Retrieves package metadata details
- `application list` - Aggregates installed flatpaks and system packages
- `application search <query>` - Searches package databases

### `app_sync`
Low-footprint background synchronization daemon in Rust:
- Listens for file deletion events in /Applications
- Automatically uninstalls package managers files when container or companion launcher is deleted
- Keeps local package installations in sync with /Applications layout

## Architecture

- **Base:** Arch Linux with curated rolling release
- **Kernel:** Linux-Zen for ultra-low latency
- **Filesystem:** Btrfs with automated snapshots via Snapper
- **Desktop:** KDE Plasma with macOS-like customization
- **Audio:** PipeWire for sub-10ms latency
- **Graphics:** DXVK/VKD3D-Proton for DirectX->Vulkan translation
- **Windows Apps:** Wine/Proton with GPU compute passthrough

See `ROADMAP.md` for the staged plan from installable prototype to a real Conjunction distro.

## Project Structure

```
conjunction/
├── archiso/
│   ├── airootfs/
│   │   ├── etc/
│   │   │   ├── sddm.conf.d/
│   │   │   │   └── conjunction.conf
│   │   │   └── systemd/system/
│   │   │       ├── conjunction-setup.service
│   │   │       └── getty@tty1.service.d/
│   │   │           └── autologin.conf
│   │   └── usr/local/bin/
│   │       ├── conjunction-installer.sh
│   │       └── conjunction-live-setup.sh
│   ├── packages.x86_64
│   └── profiledef.sh
├── setup_conjunction_ui.sh
├── Cargo.toml
├── conjunction-core/
├── cj/
├── application/
├── app_sync/
├── build-iso.sh
├── build-iso-wsl.sh
└── README.md
```

## License

Conjunction OS is open-source software.