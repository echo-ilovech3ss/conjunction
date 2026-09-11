"""
Conjunction OS - Modern Welcome & System Tour Application
Fedora-style welcome center providing quick actions, system diagnostics,
desktop appearance setup, documentation links, and installer launch.
"""

import os
import sys
import subprocess
import webbrowser
import tkinter as tk
from tkinter import ttk, messagebox
from pathlib import Path
from typing import Optional

from .theme import Palette, apply_conjunction_theme, ModernCard
from .backend import SystemDiscovery
from .logo import render_logo_png, export_all_brand_assets

try:
    from PIL import Image, ImageTk
    HAS_PIL = True
except ImportError:
    HAS_PIL = False


class ConjunctionWelcomeApp:
    """Modern Welcome & Setup Hub for Conjunction OS live ISO and installed system."""

    def __init__(self, root: Optional[tk.Tk] = None, test_mode: bool = False):
        self.test_mode = test_mode
        if root is None:
            self.root = tk.Tk()
            self.root.title("Welcome to Conjunction OS")
            self.root.geometry("860x580")
            self.root.minsize(780, 500)
            self.root.configure(bg=Palette.BG_DARK)
        else:
            self.root = root

        self.style = apply_conjunction_theme(self.root)
        self.specs = SystemDiscovery.get_system_specs()

        self.logo_header: Optional[Any] = None
        self.logo_hero: Optional[Any] = None
        self._load_brand_assets()

        self._build_ui()

    def _load_brand_assets(self):
        base_dir = Path(__file__).parent.parent / "assets"
        header_png = base_dir / "icons" / "conjunction-32.png"
        hero_png = base_dir / "conjunction.png"

        if not header_png.exists() or not hero_png.exists():
            try:
                export_all_brand_assets(str(base_dir))
            except Exception:
                pass

        if HAS_PIL and header_png.exists():
            try:
                im_hdr = Image.open(str(header_png)).resize((28, 28), Image.Resampling.LANCZOS)
                self.logo_header = ImageTk.PhotoImage(im_hdr)
            except Exception:
                pass

        if HAS_PIL and hero_png.exists():
            try:
                im_hero = Image.open(str(hero_png)).resize((92, 92), Image.Resampling.LANCZOS)
                self.logo_hero = ImageTk.PhotoImage(im_hero)
            except Exception:
                pass

    def _build_ui(self):
        # 1. Header Bar
        header = tk.Frame(self.root, bg=Palette.BG_SIDEBAR, height=52)
        header.pack(side=tk.TOP, fill=tk.X)
        header.pack_propagate(False)

        h_content = tk.Frame(header, bg=Palette.BG_SIDEBAR)
        h_content.pack(side=tk.LEFT, fill=tk.Y, padx=16, pady=8)

        if self.logo_header:
            tk.Label(h_content, image=self.logo_header, bg=Palette.BG_SIDEBAR).pack(side=tk.LEFT, padx=(0, 10))
        else:
            tk.Label(h_content, text="✦", font=("Segoe UI", 16, "bold"),
                     fg=Palette.ACCENT_CYAN, bg=Palette.BG_SIDEBAR).pack(side=tk.LEFT, padx=(0, 8))

        tk.Label(h_content, text="CONJUNCTION OS", font=("Segoe UI", 12, "bold"),
                 fg=Palette.TEXT_PRIMARY, bg=Palette.BG_SIDEBAR).pack(side=tk.LEFT)

        tk.Label(h_content, text="WELCOME & SETUP", font=("Segoe UI", 9, "bold"),
                 fg=Palette.ACCENT_CYAN, bg=Palette.BG_SIDEBAR).pack(side=tk.LEFT, padx=(8, 0))

        tk.Frame(self.root, bg=Palette.BORDER_DEFAULT, height=1).pack(side=tk.TOP, fill=tk.X)

        # 2. Main Body Container
        body = tk.Frame(self.root, bg=Palette.BG_DARK)
        body.pack(side=tk.TOP, fill=tk.BOTH, expand=True, padx=24, pady=20)

        # Top Hero Card
        hero_card = ModernCard(body, height=120)
        hero_card.pack(fill=tk.X, pady=(0, 18))

        h_inner = tk.Frame(hero_card, bg=Palette.BG_CARD)
        hero_card.create_window(16, 14, anchor="nw", window=h_inner)

        if self.logo_hero:
            tk.Label(h_inner, image=self.logo_hero, bg=Palette.BG_CARD).pack(side=tk.LEFT, padx=(0, 16))

        hero_text = tk.Frame(h_inner, bg=Palette.BG_CARD)
        hero_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        tk.Label(hero_text, text="Welcome to Conjunction OS", font=("Segoe UI", 16, "bold"),
                 fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).pack(anchor="w")

        tk.Label(hero_text, text="Next-Generation Arch Linux with macOS Simplicity and Windows Application Layer",
                 font=("Segoe UI", 9), fg=Palette.TEXT_ACCENT, bg=Palette.BG_CARD).pack(anchor="w", pady=(2, 4))

        tk.Label(hero_text, text="Select an action below to install the system, explore documentation, or customize your desktop.",
                 font=("Segoe UI", 8), fg=Palette.TEXT_SECONDARY, bg=Palette.BG_CARD).pack(anchor="w")

        # Action Cards Grid (2 columns)
        grid_frame = tk.Frame(body, bg=Palette.BG_DARK)
        grid_frame.pack(fill=tk.BOTH, expand=True)

        cards_data = [
            ("Install Conjunction OS", "Launch graphical installer to deploy to storage drive", "install", Palette.ACCENT_CYAN),
            ("System Diagnostics", "Inspect hardware health, memory, and network state", "diag", Palette.ACCENT_BLUE),
            ("Configure Desktop Theme", "Setup macOS WhiteSur look, global menu, and Plank dock", "theme", Palette.ACCENT_PURPLE),
            ("Software & Package Manager", "Browse apps with Flatpak, pacman, and cj CLI", "software", Palette.ACCENT_EMERALD),
            ("Hardware Summary", "View CPU, GPU, and memory specifications", "hw", Palette.TEXT_ACCENT),
            ("Documentation & Community", "Arch Linux Wiki and Conjunction OS guides", "docs", Palette.TEXT_SECONDARY),
        ]

        for i, (title, subtitle, action_key, col) in enumerate(cards_data):
            row = i // 2
            col_idx = i % 2

            card = ModernCard(grid_frame, height=80, width=380)
            card.grid(row=row, column=col_idx, padx=8, pady=8, sticky="nsew")
            grid_frame.grid_columnconfigure(col_idx, weight=1)

            c_inner = tk.Frame(card, bg=Palette.BG_CARD)
            card.create_window(14, 12, anchor="nw", window=c_inner)

            def make_handler(k=action_key):
                return lambda e=None: self._on_action(k)

            card.bind("<Button-1>", make_handler())
            c_inner.bind("<Button-1>", make_handler())

            top_row = tk.Frame(c_inner, bg=Palette.BG_CARD)
            top_row.pack(fill=tk.X)
            top_row.bind("<Button-1>", make_handler())

            bullet = tk.Label(top_row, text="✦", font=("Segoe UI", 11, "bold"), fg=col, bg=Palette.BG_CARD)
            bullet.pack(side=tk.LEFT, padx=(0, 8))
            bullet.bind("<Button-1>", make_handler())

            t_lbl = tk.Label(top_row, text=title, font=("Segoe UI", 10, "bold"),
                             fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD)
            t_lbl.pack(side=tk.LEFT)
            t_lbl.bind("<Button-1>", make_handler())

            s_lbl = tk.Label(c_inner, text=subtitle, font=("Segoe UI", 8),
                             fg=Palette.TEXT_SECONDARY, bg=Palette.BG_CARD, wraplength=340, justify="left")
            s_lbl.pack(anchor="w", padx=(22, 0), pady=(4, 0))
            s_lbl.bind("<Button-1>", make_handler())

        # 3. Bottom Footer
        tk.Frame(self.root, bg=Palette.BORDER_DEFAULT, height=1).pack(side=tk.BOTTOM, fill=tk.X)
        footer = tk.Frame(self.root, bg=Palette.BG_SIDEBAR, height=48)
        footer.pack(side=tk.BOTTOM, fill=tk.X)
        footer.pack_propagate(False)

        # Autostart checkbox
        self.var_autostart = tk.BooleanVar(value=True)
        chk = ttk.Checkbutton(footer, text="Show this welcome window on boot",
                              variable=self.var_autostart, style="Card.TCheckbutton")
        chk.pack(side=tk.LEFT, padx=16, pady=12)

        close_btn = ttk.Button(footer, text="Close", style="Secondary.TButton", command=self.root.destroy)
        close_btn.pack(side=tk.RIGHT, padx=16, pady=10)

    def _on_action(self, key: str):
        if key == "install":
            self._launch_installer()
        elif key == "diag":
            self._show_diagnostics()
        elif key == "theme":
            self._run_ui_setup()
        elif key == "software":
            self._show_software_guide()
        elif key == "hw":
            self._show_hardware_info()
        elif key == "docs":
            webbrowser.open("https://archlinux.org")

    def _launch_installer(self):
        installer_script = Path("/usr/local/bin/conjunction-installer-gui")
        if installer_script.exists():
            subprocess.Popen(["sudo", str(installer_script)])
        else:
            # Launch internal installer
            from .installer import ConjunctionInstallerApp
            top = tk.Toplevel(self.root)
            top.title("Install Conjunction OS")
            top.geometry("980x660")
            ConjunctionInstallerApp(root=top, dry_run=True)

    def _show_diagnostics(self):
        diag_msg = (
            f"Firmware Mode: {'UEFI' if self.specs.is_uefi else 'Legacy BIOS'}\n"
            f"Processor: {self.specs.cpu_model}\n"
            f"RAM Memory: {self.specs.ram_free_gb} GB free / {self.specs.ram_total_gb} GB total\n"
            f"Network: {'Connected' if self.specs.is_network_connected else 'Disconnected'}\n"
            f"Live Space: {self.specs.live_disk_free_gb} GB free\n"
        )
        messagebox.showinfo("System Diagnostics", diag_msg)

    def _show_hardware_info(self):
        hw_msg = (
            f"CPU: {self.specs.cpu_model}\n"
            f"Memory: {self.specs.ram_total_gb} GB Total\n"
            f"Boot Target: x86_64\n"
            f"Display Server: X11 / Wayland Plasma Session\n"
        )
        messagebox.showinfo("Hardware Summary", hw_msg)

    def _run_ui_setup(self):
        ui_script = Path("/opt/conjunction/setup_conjunction_ui.sh")
        if ui_script.exists():
            subprocess.Popen(["konsole", "-e", "sudo", str(ui_script)])
        else:
            messagebox.showinfo("Theme Setup", "Theme setup script located at /opt/conjunction/setup_conjunction_ui.sh")

    def _show_software_guide(self):
        guide = (
            "Conjunction OS Package Ecosystem:\n\n"
            "• cj install <app>: Unified installer with automatic container isolation\n"
            "• flatpak install flathub <app>: Sandboxed desktop apps\n"
            "• pacman -S <pkg>: Official Arch Linux repositories\n"
            "• Windows applications: Double-click .exe/.msi or install via cj"
        )
        messagebox.showinfo("Software Management", guide)

    def run(self):
        if not self.test_mode:
            self.root.mainloop()


def main():
    app = ConjunctionWelcomeApp()
    def report_ready():
        runtime = os.environ.get("XDG_RUNTIME_DIR")
        if runtime and Path("/etc/archiso-release").exists() and app.root.winfo_ismapped():
            (Path(runtime) / "conjunction-welcome.ready").touch()
    app.root.after(1000, report_ready)
    app.run()


if __name__ == "__main__":
    main()
