# Conjunction OS Asset & Theme Licenses

This document records the upstream sources, verified licenses, and modifications
applied to third-party fonts, icon themes, and GTK/desktop themes bundled into
Conjunction OS (`os/Containerfile`).

| Asset | Version / Source | Upstream License | Notes & Modifications |
|---|---|---|---|
| **Inter & Inter Display** | `v4.1` — `https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip` | `OFL-1.1` (SIL Open Font License 1.1) | Installed to `/usr/share/fonts/inter/`; license text installed at `/usr/share/licenses/conjunction/Inter-OFL-1.1.txt`. |
| **JetBrains Mono** | Fedora package `jetbrains-mono-fonts-all` (`2.304`, `https://jetbrains.com/mono/`) | `OFL-1.1` (SIL Open Font License 1.1) | Installed via Fedora RPM (`dnf5 install jetbrains-mono-fonts-all`). |
| **Material Symbols Rounded** | `https://github.com/google/material-design-icons` (`variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf`) | `Apache-2.0` | Installed to `/usr/share/fonts/material-symbols/`; license text installed at `/usr/share/licenses/conjunction/MaterialSymbolsRounded-Apache-2.0.txt`. |
| **MacTahoe-icon-theme** | `https://github.com/vinceliuice/MacTahoe-icon-theme` (`main`) | `GPL-3.0` (`COPYING`) | Installed to `/usr/share/icons/MacTahoe*`. Trademarked `start-here*` / `distributor-logo*` icons are replaced with `assets/conjunction-mark.svg`, and `safari*` / `system-file-manager*` icons are replaced with non-trademark generic equivalents during image build. `COPYING` and `AUTHORS` are preserved in each theme directory and `/usr/share/licenses/conjunction/MacTahoe-icon-theme-GPL-3.0.txt`. |
| **MacTahoe-gtk-theme** | `https://github.com/vinceliuice/MacTahoe-gtk-theme` (`main`) | `MIT` (`COPYING`, Copyright (c) 2021 WhiteSur Developers) | Note: `docs/design/ASSETS.md` tentatively noted `GPL-3.0`, whereas the upstream repository's `COPYING` file specifies `MIT`. Installed to `/usr/share/themes/MacTahoe*`; license preserved at `/usr/share/licenses/conjunction/MacTahoe-gtk-theme-MIT.txt`. |
| **Phosphor Icons** | `data/icons/phosphor/` (`Copyright (c) 2023 Phosphor Icons`) | `MIT` ([`data/icons/phosphor/LICENSE`](../data/icons/phosphor/LICENSE)) | Bundled into `/usr/share/conjunction/icons/phosphor/` by `conjunction-design`. |
| **FEX-Emu** | Fedora `fex-emu` / `fex-emu-thunks` / `fex-emu-rootfs-fedora` (`aarch64`, `2604`) | `MIT` (FEX) / Fedora RootFS aggregate licenses | x86/x86_64 usermode emulator + `binfmt_misc` + Fedora 45 x86_64 EROFS RootFS (`aarch64` image). |
| **Wine-Proton WoW64 (`aarch64` runtime)** | `https://github.com/Kron4ek/Wine-Builds/releases/download/proton-11.0-3/wine-proton-11.0-3-amd64-wow64.tar.xz` | `LGPL-2.1-or-later` (Wine / Proton) | Bundled on `aarch64` under `/usr/share/conjunction/wine-x86_64/` and invoked via `/usr/bin/FEXInterpreter`. |
| **Conjunction Logos & Icons** | Repository `assets/` | Conjunction Project | First-party project artwork used for OS identity, app icon (`hicolor`), Plymouth boot splash, and Anaconda branding. |
