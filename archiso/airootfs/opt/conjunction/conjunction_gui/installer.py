"""
Conjunction OS - Fedora-Style Modern Graphical Installer
A sleek, developer-grade installer application inspired by Fedora Anaconda and macOS WhiteSur.
Integrates custom storage selection, user account creation, system tuning,
real-time installation progress streaming, and the Conjunction celestial God Logo.
"""

import os
import sys
import time
import queue
import argparse
import subprocess
import tkinter as tk
from tkinter import ttk, messagebox
from pathlib import Path
from typing import Optional, List, Dict, Any

from .theme import (
    Palette, apply_conjunction_theme, ModernCard,
    PartitionVisualBar, PasswordStrengthBar
)
from .backend import (
    DiskInfo, SystemSpecs, InstallConfig,
    SystemDiscovery, Validation, InstallationRunner
)
from .logo import render_logo_png, export_all_brand_assets

try:
    from PIL import Image, ImageTk
    HAS_PIL = True
except ImportError:
    HAS_PIL = False


class ConjunctionInstallerApp:
    """Main Conjunction OS Graphical Installer Application."""

    def __init__(self, root: Optional[tk.Tk] = None, dry_run: bool = False, test_mode: bool = False):
        self.dry_run = dry_run
        self.test_mode = test_mode
        self.owns_root = root is None

        if root is None:
            self.root = tk.Tk()
            self.root.title("Install Conjunction OS")
            self.root.geometry("980x660")
            self.root.minsize(860, 580)
            self.root.configure(bg=Palette.BG_DARK)
        else:
            self.root = root

        self.style = apply_conjunction_theme(self.root)
        self.config = InstallConfig(is_dry_run=dry_run)

        # Discovered hardware & disks
        self.system_specs = SystemDiscovery.get_system_specs()
        self.available_disks = SystemDiscovery.get_available_disks()
        if self.available_disks:
            self.config.target_disk = self.available_disks[0].name
            self.config.part_scheme = 1 if self.system_specs.is_uefi else 2

        # Step navigation state
        self.current_step = 0
        self.step_names = [
            ("Welcome", "System Overview"),
            ("Storage", "Disk & Partitions"),
            ("User Account", "Credentials & Sudo"),
            ("Preferences", "System Settings"),
            ("Summary", "Review & Confirm"),
            ("Installing", "Live Deployment"),
            ("Completed", "Finished")
        ]

        # Assets & Images
        self.logo_img_header: Optional[Any] = None
        self.logo_img_hero: Optional[Any] = None
        self.disk_card_widgets: List[ModernCard] = []
        self._load_brand_assets()

        # Thread queue for background installer events
        self.event_queue: queue.Queue = queue.Queue()
        self.runner: Optional[InstallationRunner] = None

        # Build UI layout
        self._build_shell()
        self._show_step(0)

        # Polling background installer events
        self.root.after(100, self._process_events)

    def _load_brand_assets(self):
        """Loads and prepares Conjunction OS God Logo icons."""
        # Find or export assets
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
                self.logo_img_header = ImageTk.PhotoImage(im_hdr)
            except Exception:
                pass

        if HAS_PIL and hero_png.exists():
            try:
                im_hero = Image.open(str(hero_png)).resize((110, 110), Image.Resampling.LANCZOS)
                self.logo_img_hero = ImageTk.PhotoImage(im_hero)
            except Exception:
                pass

    def _build_shell(self):
        """Builds header bar, sidebar stepper, central page container, and footer bar."""
        # 1. Top Header Bar
        self.header_frame = tk.Frame(self.root, bg=Palette.BG_SIDEBAR, height=52)
        self.header_frame.pack(side=tk.TOP, fill=tk.X)
        self.header_frame.pack_propagate(False)

        header_content = tk.Frame(self.header_frame, bg=Palette.BG_SIDEBAR)
        header_content.pack(side=tk.LEFT, fill=tk.Y, padx=16, pady=8)

        if self.logo_img_header:
            logo_lbl = tk.Label(header_content, image=self.logo_img_header, bg=Palette.BG_SIDEBAR)
            logo_lbl.pack(side=tk.LEFT, padx=(0, 10))
        else:
            # Fallback text badge
            badge = tk.Label(header_content, text="✦", font=("Segoe UI", 16, "bold"),
                             fg=Palette.ACCENT_CYAN, bg=Palette.BG_SIDEBAR)
            badge.pack(side=tk.LEFT, padx=(0, 8))

        title_lbl = tk.Label(header_content, text="CONJUNCTION OS",
                             font=("Segoe UI", 12, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_SIDEBAR)
        title_lbl.pack(side=tk.LEFT)

        tag_lbl = tk.Label(header_content, text="INSTALLER",
                           font=("Segoe UI", 9, "bold"), fg=Palette.ACCENT_CYAN, bg=Palette.BG_SIDEBAR)
        tag_lbl.pack(side=tk.LEFT, padx=(8, 0))

        # Right header badges
        hdr_right = tk.Frame(self.header_frame, bg=Palette.BG_SIDEBAR)
        hdr_right.pack(side=tk.RIGHT, fill=tk.Y, padx=16, pady=10)

        uefi_text = "UEFI Mode" if self.system_specs.is_uefi else "BIOS Mode"
        uefi_lbl = tk.Label(hdr_right, text=f"• {uefi_text}", font=("Segoe UI", 9),
                            fg=Palette.TEXT_SECONDARY, bg=Palette.BG_SIDEBAR)
        uefi_lbl.pack(side=tk.LEFT, padx=6)

        if self.dry_run:
            dry_badge = tk.Label(hdr_right, text="[DRY-RUN SIMULATION]", font=("Segoe UI", 8, "bold"),
                                 fg=Palette.ACCENT_AMBER, bg=Palette.BG_SIDEBAR)
            dry_badge.pack(side=tk.LEFT, padx=6)

        # Divider under header
        tk.Frame(self.root, bg=Palette.BORDER_DEFAULT, height=1).pack(side=tk.TOP, fill=tk.X)

        # 2. Main Workspace (Sidebar + Content)
        self.body_frame = tk.Frame(self.root, bg=Palette.BG_DARK)
        self.body_frame.pack(side=tk.TOP, fill=tk.BOTH, expand=True)

        # Left Sidebar (Fedora-Style Stepper)
        self.sidebar_frame = tk.Frame(self.body_frame, bg=Palette.BG_SIDEBAR, width=220)
        self.sidebar_frame.pack(side=tk.LEFT, fill=tk.Y)
        self.sidebar_frame.pack_propagate(False)

        tk.Frame(self.body_frame, bg=Palette.BORDER_DEFAULT, width=1).pack(side=tk.LEFT, fill=tk.Y)

        self._build_stepper()

        # Center Content Area
        self.content_frame = tk.Frame(self.body_frame, bg=Palette.BG_DARK)
        self.content_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=24, pady=20)

        # 3. Bottom Navigation Footer Bar
        tk.Frame(self.root, bg=Palette.BORDER_DEFAULT, height=1).pack(side=tk.BOTTOM, fill=tk.X)
        self.footer_frame = tk.Frame(self.root, bg=Palette.BG_SIDEBAR, height=58)
        self.footer_frame.pack(side=tk.BOTTOM, fill=tk.X)
        self.footer_frame.pack_propagate(False)

        self.btn_quit = ttk.Button(self.footer_frame, text="Quit", style="Secondary.TButton",
                                    command=self._on_quit)
        self.btn_quit.pack(side=tk.LEFT, padx=16, pady=12)

        self.btn_next = ttk.Button(self.footer_frame, text="Next", style="Primary.TButton",
                                    command=self._on_next)
        self.btn_next.pack(side=tk.RIGHT, padx=16, pady=12)

        self.btn_back = ttk.Button(self.footer_frame, text="Back", style="Secondary.TButton",
                                    command=self._on_back)
        self.btn_back.pack(side=tk.RIGHT, padx=(0, 8), pady=12)

    def _build_stepper(self):
        """Creates the step indicator items in the left sidebar."""
        self.stepper_items = []
        container = tk.Frame(self.sidebar_frame, bg=Palette.BG_SIDEBAR)
        container.pack(fill=tk.BOTH, expand=True, padx=12, pady=18)

        for i, (title, subtitle) in enumerate(self.step_names):
            item_frame = tk.Frame(container, bg=Palette.BG_SIDEBAR, pady=6)
            item_frame.pack(fill=tk.X)

            icon_lbl = tk.Label(item_frame, text=str(i + 1), font=("Segoe UI", 9, "bold"),
                                width=3, fg=Palette.TEXT_MUTED, bg=Palette.BG_CARD)
            icon_lbl.pack(side=tk.LEFT, padx=(0, 10))

            text_frame = tk.Frame(item_frame, bg=Palette.BG_SIDEBAR)
            text_frame.pack(side=tk.LEFT, fill=tk.X)

            title_lbl = tk.Label(text_frame, text=title, font=("Segoe UI", 10, "bold"),
                                 fg=Palette.TEXT_MUTED, bg=Palette.BG_SIDEBAR, anchor="w")
            title_lbl.pack(fill=tk.X)

            sub_lbl = tk.Label(text_frame, text=subtitle, font=("Segoe UI", 8),
                               fg=Palette.TEXT_MUTED, bg=Palette.BG_SIDEBAR, anchor="w")
            sub_lbl.pack(fill=tk.X)

            self.stepper_items.append({
                "frame": item_frame,
                "icon": icon_lbl,
                "title": title_lbl,
                "subtitle": sub_lbl
            })

    def _update_stepper_ui(self):
        """Updates the sidebar step indicators according to current step."""
        for i, item in enumerate(self.stepper_items):
            if i < self.current_step:
                # Completed
                item["icon"].configure(text="✓", fg=Palette.ACCENT_EMERALD, bg=Palette.BG_CARD)
                item["title"].configure(fg=Palette.TEXT_PRIMARY)
                item["subtitle"].configure(fg=Palette.TEXT_SECONDARY)
            elif i == self.current_step:
                # Active
                item["icon"].configure(text="●", fg=Palette.ACCENT_CYAN, bg=Palette.BG_CARD_SELECTED)
                item["title"].configure(fg=Palette.ACCENT_CYAN)
                item["subtitle"].configure(fg=Palette.TEXT_PRIMARY)
            else:
                # Upcoming
                item["icon"].configure(text=str(i + 1), fg=Palette.TEXT_MUTED, bg=Palette.BG_CARD)
                item["title"].configure(fg=Palette.TEXT_MUTED)
                item["subtitle"].configure(fg=Palette.TEXT_MUTED)

    def _clear_content(self):
        for child in self.content_frame.winfo_children():
            child.destroy()

    def _show_step(self, step_idx: int):
        self.current_step = step_idx
        self._update_stepper_ui()
        self._clear_content()

        # Update footer buttons
        self.btn_back.configure(state=tk.NORMAL if 0 < step_idx < 5 else tk.DISABLED)
        if step_idx < 4:
            self.btn_next.configure(text="Next", state=tk.NORMAL)
        elif step_idx == 4:
            self.btn_next.configure(text="Install Conjunction OS", state=tk.NORMAL)
        elif step_idx == 5:
            self.btn_back.configure(state=tk.DISABLED)
            self.btn_next.configure(text="Installing...", state=tk.DISABLED)
        elif step_idx == 6:
            self.btn_back.configure(state=tk.DISABLED)
            self.btn_next.configure(text="Reboot Now", state=tk.NORMAL)
            self.btn_quit.configure(text="Quit to Desktop", state=tk.NORMAL)

        # Render corresponding page
        if step_idx == 0:
            self._render_welcome_page()
        elif step_idx == 1:
            self._render_storage_page()
        elif step_idx == 2:
            self._render_user_page()
        elif step_idx == 3:
            self._render_settings_page()
        elif step_idx == 4:
            self._render_summary_page()
        elif step_idx == 5:
            self._render_installing_page()
        elif step_idx == 6:
            self._render_completed_page()

    # ─── PAGE 1: WELCOME & SYSTEM READINESS ──────────────────────────────────
    def _render_welcome_page(self):
        # Hero card
        hero_card = ModernCard(self.content_frame, height=140)
        hero_card.pack(fill=tk.X, pady=(0, 16))

        hero_inner = tk.Frame(hero_card, bg=Palette.BG_CARD)
        hero_card.create_window(16, 16, anchor="nw", window=hero_inner)

        if self.logo_img_hero:
            img_lbl = tk.Label(hero_inner, image=self.logo_img_hero, bg=Palette.BG_CARD)
            img_lbl.pack(side=tk.LEFT, padx=(0, 20))

        text_box = tk.Frame(hero_inner, bg=Palette.BG_CARD)
        text_box.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        tk.Label(text_box, text="Welcome to Conjunction OS", font=("Segoe UI", 18, "bold"),
                 fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).pack(anchor="w")

        tk.Label(text_box, text="Arch Linux foundation · macOS ergonomics · Windows application compatibility",
                 font=("Segoe UI", 10), fg=Palette.TEXT_ACCENT, bg=Palette.BG_CARD).pack(anchor="w", pady=(2, 8))

        desc = ("This installer will guide you through setting up storage, user accounts, and system "
                "preferences. Conjunction OS features Btrfs snapshots, PipeWire low-latency audio, and "
                "integrated Wine/Proton isolation.")
        tk.Label(text_box, text=desc, font=("Segoe UI", 9), fg=Palette.TEXT_SECONDARY,
                 bg=Palette.BG_CARD, wraplength=560, justify="left").pack(anchor="w")

        # Hardware & Readiness Checklist
        chk_header = tk.Label(self.content_frame, text="System Verification",
                              font=("Segoe UI", 12, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_DARK)
        chk_header.pack(anchor="w", pady=(10, 8))

        grid_frame = tk.Frame(self.content_frame, bg=Palette.BG_DARK)
        grid_frame.pack(fill=tk.BOTH, expand=True)

        specs = [
            ("Processor (CPU)", self.system_specs.cpu_model, True),
            ("System Memory", f"{self.system_specs.ram_total_gb} GB RAM ({self.system_specs.ram_free_gb} GB available)",
             self.system_specs.ram_total_gb >= 2.0),
            ("Firmware Boot Mode", "UEFI (Modern GPT)" if self.system_specs.is_uefi else "Legacy BIOS (MBR)", True),
            ("Internet Connectivity", "Connected to internet" if self.system_specs.is_network_connected else "Offline (Offline cache used)",
             self.system_specs.is_network_connected),
            ("Installation Media", f"{self.system_specs.live_disk_free_gb} GB free live space", True),
        ]

        for i, (title, val, ok) in enumerate(specs):
            card = ModernCard(grid_frame, height=48)
            card.pack(fill=tk.X, pady=4)
            row = tk.Frame(card, bg=Palette.BG_CARD)
            card.create_window(12, 10, anchor="nw", window=row)

            icon_col = Palette.ACCENT_EMERALD if ok else Palette.ACCENT_AMBER
            icon_char = "✔" if ok else "▲"
            tk.Label(row, text=icon_char, font=("Segoe UI", 11, "bold"), fg=icon_col, bg=Palette.BG_CARD).pack(side=tk.LEFT, padx=(0, 10))
            tk.Label(row, text=title, font=("Segoe UI", 9, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD, width=22, anchor="w").pack(side=tk.LEFT)
            tk.Label(row, text=val, font=("Segoe UI", 9), fg=Palette.TEXT_SECONDARY, bg=Palette.BG_CARD).pack(side=tk.LEFT)

    # ─── PAGE 2: STORAGE & PARTITION SELECTION ───────────────────────────────
    def _render_storage_page(self):
        tk.Label(self.content_frame, text="Storage Destination & Partitions",
                 font=("Segoe UI", 14, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_DARK).pack(anchor="w")

        tk.Label(self.content_frame, text="Select the drive to install Conjunction OS. Btrfs subvolumes will be created.",
                 font=("Segoe UI", 9), fg=Palette.TEXT_SECONDARY, bg=Palette.BG_DARK).pack(anchor="w", pady=(2, 12))

        # List of detected disks
        self.disk_card_widgets = []
        disks_container = tk.Frame(self.content_frame, bg=Palette.BG_DARK)
        disks_container.pack(fill=tk.X, pady=(0, 12))

        for disk in self.available_disks:
            card = ModernCard(disks_container, height=64)
            card.pack(fill=tk.X, pady=4)
            if disk.name == self.config.target_disk:
                card.set_selected(True)

            card_inner = tk.Frame(card, bg=Palette.BG_CARD_SELECTED if disk.name == self.config.target_disk else Palette.BG_CARD)
            card.create_window(12, 8, anchor="nw", window=card_inner)

            # Click handler to select disk
            def make_click_handler(d_name=disk.name, c=card, ci=card_inner):
                def _select(event=None):
                    self.config.target_disk = d_name
                    for other_card in self.disk_card_widgets:
                        other_card.set_selected(False)
                    c.set_selected(True)
                return _select

            handler = make_click_handler()
            card.bind("<Button-1>", handler)
            card_inner.bind("<Button-1>", handler)

            # Disk Icon and Name
            top_line = tk.Frame(card_inner, bg=card_inner["bg"])
            top_line.pack(fill=tk.X)
            top_line.bind("<Button-1>", handler)

            radio_char = "◉" if disk.name == self.config.target_disk else "○"
            rad_lbl = tk.Label(top_line, text=radio_char, font=("Segoe UI", 12),
                               fg=Palette.ACCENT_CYAN, bg=card_inner["bg"])
            rad_lbl.pack(side=tk.LEFT, padx=(0, 8))
            rad_lbl.bind("<Button-1>", handler)

            d_title = tk.Label(top_line, text=f"/dev/{disk.name}  —  {disk.size_human}",
                               font=("Segoe UI", 10, "bold"), fg=Palette.TEXT_PRIMARY, bg=card_inner["bg"])
            d_title.pack(side=tk.LEFT)
            d_title.bind("<Button-1>", handler)

            type_badge = tk.Label(top_line, text=f" [{disk.disk_type_label}] ",
                                  font=("Segoe UI", 8, "bold"), fg=Palette.ACCENT_CYAN, bg=card_inner["bg"])
            type_badge.pack(side=tk.LEFT, padx=6)
            type_badge.bind("<Button-1>", handler)

            d_model = tk.Label(card_inner, text=f"Model: {disk.model}", font=("Segoe UI", 8),
                               fg=Palette.TEXT_SECONDARY, bg=card_inner["bg"])
            d_model.pack(anchor="w", padx=(28, 0))
            d_model.bind("<Button-1>", handler)

            self.disk_card_widgets.append(card)

        # Partitioning Method
        part_box = ModernCard(self.content_frame, height=130)
        part_box.pack(fill=tk.X, pady=(4, 12))

        part_inner = tk.Frame(part_box, bg=Palette.BG_CARD)
        part_box.create_window(14, 10, anchor="nw", window=part_inner)

        tk.Label(part_inner, text="Partitioning Layout", font=("Segoe UI", 10, "bold"),
                 fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).pack(anchor="w")

        # Partition bar visualization
        pbar = PartitionVisualBar(part_inner, height=18, width=540)
        pbar.pack(fill=tk.X, pady=(6, 8))

        legend_row = tk.Frame(part_inner, bg=Palette.BG_CARD)
        legend_row.pack(fill=tk.X)
        legs = [
            ("EFI System (512M)", Palette.PART_EFI),
            ("Root / (@)", Palette.PART_ROOT),
            ("Home (@home)", Palette.PART_HOME),
            ("Snapshots (@snapshots)", Palette.PART_SNAPSHOTS)
        ]
        for leg_text, leg_col in legs:
            tk.Label(legend_row, text="■", font=("Segoe UI", 10), fg=leg_col, bg=Palette.BG_CARD).pack(side=tk.LEFT, padx=(0, 3))
            tk.Label(legend_row, text=leg_text, font=("Segoe UI", 8), fg=Palette.TEXT_SECONDARY, bg=Palette.BG_CARD).pack(side=tk.LEFT, padx=(0, 12))

        # Data wipe warning
        warn_card = ModernCard(self.content_frame, height=52, border=Palette.ACCENT_AMBER)
        warn_card.pack(fill=tk.X)
        warn_inner = tk.Frame(warn_card, bg=Palette.BG_CARD)
        warn_card.create_window(12, 10, anchor="nw", window=warn_inner)

        tk.Label(warn_inner, text="⚠️ NOTICE:", font=("Segoe UI", 9, "bold"),
                 fg=Palette.ACCENT_AMBER, bg=Palette.BG_CARD).pack(side=tk.LEFT, padx=(0, 6))
        tk.Label(warn_inner, text="Installing will re-partition and format the chosen drive. Make sure important data is backed up.",
                 font=("Segoe UI", 8), fg=Palette.TEXT_SECONDARY, bg=Palette.BG_CARD).pack(side=tk.LEFT)

    # ─── PAGE 3: USER ACCOUNT & SECURITY ─────────────────────────────────────
    def _render_user_page(self):
        tk.Label(self.content_frame, text="User Account & Security",
                 font=("Segoe UI", 14, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_DARK).pack(anchor="w")

        tk.Label(self.content_frame, text="Create your administrative user profile for Conjunction OS.",
                 font=("Segoe UI", 9), fg=Palette.TEXT_SECONDARY, bg=Palette.BG_DARK).pack(anchor="w", pady=(2, 14))

        form_card = ModernCard(self.content_frame, height=270)
        form_card.pack(fill=tk.X)

        form = tk.Frame(form_card, bg=Palette.BG_CARD)
        form_card.create_window(16, 16, anchor="nw", window=form)

        # Full Name
        tk.Label(form, text="Full Name", font=("Segoe UI", 9, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).grid(row=0, column=0, sticky="w", pady=6)
        self.entry_fullname = ttk.Entry(form, width=32)
        self.entry_fullname.insert(0, self.config.fullname or "Developer")
        self.entry_fullname.grid(row=0, column=1, sticky="w", padx=12, pady=6)

        # Username
        tk.Label(form, text="Username", font=("Segoe UI", 9, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).grid(row=1, column=0, sticky="w", pady=6)
        self.entry_username = ttk.Entry(form, width=32)
        self.entry_username.insert(0, self.config.username or "conjunction")
        self.entry_username.grid(row=1, column=1, sticky="w", padx=12, pady=6)

        self.lbl_user_val = tk.Label(form, text="", font=("Segoe UI", 8), fg=Palette.ACCENT_CRIMSON, bg=Palette.BG_CARD)
        self.lbl_user_val.grid(row=1, column=2, sticky="w", padx=6)

        # Password
        tk.Label(form, text="Password", font=("Segoe UI", 9, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).grid(row=2, column=0, sticky="w", pady=6)
        self.entry_pw = ttk.Entry(form, width=32, show="•")
        self.entry_pw.insert(0, self.config.password or "")
        self.entry_pw.grid(row=2, column=1, sticky="w", padx=12, pady=6)

        # Strength bar
        self.pw_bar = PasswordStrengthBar(form, height=6, width=180)
        self.pw_bar.grid(row=2, column=2, sticky="w", padx=6)

        # Confirm Password
        tk.Label(form, text="Confirm Password", font=("Segoe UI", 9, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).grid(row=3, column=0, sticky="w", pady=6)
        self.entry_pw_confirm = ttk.Entry(form, width=32, show="•")
        self.entry_pw_confirm.insert(0, self.config.password or "")
        self.entry_pw_confirm.grid(row=3, column=1, sticky="w", padx=12, pady=6)

        self.lbl_pw_val = tk.Label(form, text="", font=("Segoe UI", 8), fg=Palette.ACCENT_CRIMSON, bg=Palette.BG_CARD)
        self.lbl_pw_val.grid(row=3, column=2, sticky="w", padx=6)

        # Sudo and Autologin checkboxes
        self.var_admin = tk.BooleanVar(value=True)
        chk_admin = ttk.Checkbutton(form, text="Grant administrator (sudo) privileges",
                                    variable=self.var_admin, style="Card.TCheckbutton")
        chk_admin.grid(row=4, column=1, sticky="w", padx=12, pady=(10, 4))

        self.var_autologin = tk.BooleanVar(value=self.config.enable_auto_login)
        chk_auto = ttk.Checkbutton(form, text="Log in automatically without password prompt",
                                   variable=self.var_autologin, style="Card.TCheckbutton")
        chk_auto.grid(row=5, column=1, sticky="w", padx=12, pady=4)

        # Real-time validation bindings
        self.entry_pw.bind("<KeyRelease>", self._on_pw_change)
        self.entry_pw_confirm.bind("<KeyRelease>", self._on_pw_change)
        self.entry_username.bind("<KeyRelease>", self._on_username_change)

    def _on_username_change(self, event=None):
        u = self.entry_username.get().strip()
        ok, msg = Validation.validate_username(u)
        self.lbl_user_val.configure(text="" if ok else msg)

    def _on_pw_change(self, event=None):
        pw = self.entry_pw.get()
        confirm = self.entry_pw_confirm.get()
        score = Validation.calculate_password_strength(pw)
        self.pw_bar.set_strength(score)
        if confirm and pw != confirm:
            self.lbl_pw_val.configure(text="Passwords do not match")
        else:
            self.lbl_pw_val.configure(text="")

    # ─── PAGE 4: SYSTEM PREFERENCES ──────────────────────────────────────────
    def _render_settings_page(self):
        tk.Label(self.content_frame, text="System Preferences & Optimization",
                 font=("Segoe UI", 14, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_DARK).pack(anchor="w")

        tk.Label(self.content_frame, text="Configure host identification, kernel tuning, and application runtime layers.",
                 font=("Segoe UI", 9), fg=Palette.TEXT_SECONDARY, bg=Palette.BG_DARK).pack(anchor="w", pady=(2, 14))

        settings_card = ModernCard(self.content_frame, height=270)
        settings_card.pack(fill=tk.X)

        s_inner = tk.Frame(settings_card, bg=Palette.BG_CARD)
        settings_card.create_window(16, 16, anchor="nw", window=s_inner)

        # Hostname
        tk.Label(s_inner, text="Computer Hostname", font=("Segoe UI", 9, "bold"),
                 fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).grid(row=0, column=0, sticky="w", pady=6)
        self.entry_hostname = ttk.Entry(s_inner, width=28)
        self.entry_hostname.insert(0, self.config.hostname or "conjunction")
        self.entry_hostname.grid(row=0, column=1, sticky="w", padx=12, pady=6)

        # Timezone
        tk.Label(s_inner, text="Timezone", font=("Segoe UI", 9, "bold"),
                 fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).grid(row=1, column=0, sticky="w", pady=6)
        self.tz_var = tk.StringVar(value=self.config.timezone or "UTC")
        tz_box = ttk.Combobox(s_inner, textvariable=self.tz_var, width=26, state="readonly",
                              values=["UTC", "America/New_York", "America/Chicago", "America/Los_Angeles",
                                      "Europe/London", "Europe/Berlin", "Europe/Paris", "Asia/Tokyo",
                                      "Asia/Kolkata", "Asia/Singapore", "Australia/Sydney"])
        tz_box.grid(row=1, column=1, sticky="w", padx=12, pady=6)

        # Feature Checkboxes
        self.var_proton = tk.BooleanVar(value=self.config.enable_wine_proton)
        chk_proton = ttk.Checkbutton(s_inner, text="Enable Wine/Proton Application Layer (Isolated /Applications/ prefix sandbox)",
                                     variable=self.var_proton, style="Card.TCheckbutton")
        chk_proton.grid(row=2, column=0, columnspan=2, sticky="w", pady=(12, 4))

        self.var_zen = tk.BooleanVar(value=self.config.enable_zen_kernel)
        chk_zen = ttk.Checkbutton(s_inner, text="Linux-Zen Low-Latency Kernel (Optimized scheduler & compute)",
                                  variable=self.var_zen, style="Card.TCheckbutton")
        chk_zen.grid(row=3, column=0, columnspan=2, sticky="w", pady=4)

        self.var_snapper = tk.BooleanVar(value=True)
        chk_snap = ttk.Checkbutton(s_inner, text="Snapper Automated Btrfs Snapshots (Instant system rollback)",
                                   variable=self.var_snapper, style="Card.TCheckbutton")
        chk_snap.grid(row=4, column=0, columnspan=2, sticky="w", pady=4)

    # ─── PAGE 5: SUMMARY & CONFIRMATION ──────────────────────────────────────
    def _render_summary_page(self):
        tk.Label(self.content_frame, text="Ready to Install",
                 font=("Segoe UI", 14, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_DARK).pack(anchor="w")

        tk.Label(self.content_frame, text="Review your installation choices below. Click 'Install Conjunction OS' to proceed.",
                 font=("Segoe UI", 9), fg=Palette.TEXT_SECONDARY, bg=Palette.BG_DARK).pack(anchor="w", pady=(2, 12))

        summary_box = ModernCard(self.content_frame, height=220)
        summary_box.pack(fill=tk.X, pady=(0, 12))

        s_inner = tk.Frame(summary_box, bg=Palette.BG_CARD)
        summary_box.create_window(16, 14, anchor="nw", window=s_inner)

        items = [
            ("Target Drive:", f"/dev/{self.config.target_disk} (All data will be erased and formatted as Btrfs)"),
            ("Firmware Scheme:", "UEFI / GPT with 512MB EFI System Partition" if self.config.part_scheme == 1 else "Legacy BIOS / MBR"),
            ("Primary Account:", f"{self.config.username} (Administrator sudo rights granted)"),
            ("Hostname & Timezone:", f"{self.config.hostname} ({self.config.timezone})"),
            ("Ecosystem Features:", "Linux-Zen Kernel, Snapper Snapshots, WhiteSur UI, Wine/Proton Sandboxing"),
        ]

        for i, (label, val) in enumerate(items):
            tk.Label(s_inner, text=label, font=("Segoe UI", 9, "bold"), fg=Palette.TEXT_ACCENT, bg=Palette.BG_CARD, width=18, anchor="w").grid(row=i, column=0, sticky="w", pady=4)
            tk.Label(s_inner, text=val, font=("Segoe UI", 9), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).grid(row=i, column=1, sticky="w", padx=8, pady=4)

        # Danger Confirmation Notice
        danger_card = ModernCard(self.content_frame, height=58, border=Palette.ACCENT_CRIMSON)
        danger_card.pack(fill=tk.X)
        d_inner = tk.Frame(danger_card, bg=Palette.BG_CARD)
        danger_card.create_window(12, 10, anchor="nw", window=d_inner)

        tk.Label(d_inner, text="🛑 FINAL CONFIRMATION:", font=("Segoe UI", 9, "bold"),
                 fg=Palette.ACCENT_CRIMSON, bg=Palette.BG_CARD).pack(side=tk.LEFT, padx=(0, 8))
        tk.Label(d_inner, text=f"Data on /dev/{self.config.target_disk} will be permanently destroyed. Are you ready?",
                 font=("Segoe UI", 9), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).pack(side=tk.LEFT)

    # ─── PAGE 6: LIVE INSTALLATION PROGRESS ──────────────────────────────────
    def _render_installing_page(self):
        tk.Label(self.content_frame, text="Installing Conjunction OS...",
                 font=("Segoe UI", 14, "bold"), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_DARK).pack(anchor="w")

        self.lbl_step_title = tk.Label(self.content_frame, text="Starting installation...",
                                       font=("Segoe UI", 10, "bold"), fg=Palette.ACCENT_CYAN, bg=Palette.BG_DARK)
        self.lbl_step_title.pack(anchor="w", pady=(6, 4))

        # Progress bar
        self.progress_var = tk.DoubleVar(value=0.0)
        self.prog_bar = ttk.Progressbar(self.content_frame, variable=self.progress_var, maximum=100.0)
        self.prog_bar.pack(fill=tk.X, pady=(4, 12))

        # Terminal Log Output Box
        tk.Label(self.content_frame, text="Live Output Log:", font=("Segoe UI", 9),
                 fg=Palette.TEXT_SECONDARY, bg=Palette.BG_DARK).pack(anchor="w")

        log_frame = tk.Frame(self.content_frame, bg=Palette.BG_INPUT)
        log_frame.pack(fill=tk.BOTH, expand=True, pady=(4, 0))

        self.log_text = tk.Text(log_frame, bg=Palette.BG_INPUT, fg="#38bdf8",
                                font=("Consolas", 9), insertbackground=Palette.ACCENT_CYAN,
                                relief="flat", wrap="none")
        scroll_y = ttk.Scrollbar(log_frame, orient="vertical", command=self.log_text.yview)
        self.log_text.configure(yscrollcommand=scroll_y.set)

        scroll_y.pack(side=tk.RIGHT, fill=tk.Y)
        self.log_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # Launch background installation
        self._start_install_process()

    def _start_install_process(self):
        """Launches the background installer thread."""
        def progress_callback(step_curr, step_tot, step_name, pct, log_line):
            self.event_queue.put(("progress", step_curr, step_tot, step_name, pct, log_line))

        def complete_callback(success, error_msg):
            self.event_queue.put(("complete", success, error_msg))

        self.runner = InstallationRunner(
            config=self.config,
            on_progress=progress_callback,
            on_complete=complete_callback
        )
        self.runner.start()

    def _process_events(self):
        """Processes background installer events on the Tkinter main thread."""
        try:
            while True:
                evt = self.event_queue.get_nowait()
                kind = evt[0]
                if kind == "progress":
                    _, curr, tot, name, pct, log_line = evt
                    if hasattr(self, "progress_var"):
                        self.progress_var.set(pct)
                    if hasattr(self, "lbl_step_title"):
                        self.lbl_step_title.configure(text=f"Step {curr}/{tot}: {name} ({int(pct)}%)")
                    if hasattr(self, "log_text"):
                        self.log_text.insert(tk.END, f"{log_line}\n")
                        self.log_text.see(tk.END)
                elif kind == "complete":
                    _, success, err = evt
                    if success:
                        self._show_step(6)
                    else:
                        messagebox.showerror("Installation Error", f"Installation failed: {err}")
        except queue.Empty:
            pass

        self.root.after(100, self._process_events)

    # ─── PAGE 7: COMPLETED ───────────────────────────────────────────────────
    def _render_completed_page(self):
        center_card = ModernCard(self.content_frame, height=360)
        center_card.pack(fill=tk.BOTH, expand=True)

        c_inner = tk.Frame(center_card, bg=Palette.BG_CARD)
        center_card.create_window(24, 24, anchor="nw", window=c_inner)

        if self.logo_img_hero:
            tk.Label(c_inner, image=self.logo_img_hero, bg=Palette.BG_CARD).pack(anchor="w", pady=(0, 10))

        tk.Label(c_inner, text="Installation Complete!", font=("Segoe UI", 18, "bold"),
                 fg=Palette.ACCENT_EMERALD, bg=Palette.BG_CARD).pack(anchor="w")

        tk.Label(c_inner, text="Conjunction OS has been deployed to your system successfully.",
                 font=("Segoe UI", 11), fg=Palette.TEXT_PRIMARY, bg=Palette.BG_CARD).pack(anchor="w", pady=(4, 14))

        notes = (
            "• Linux-Zen Kernel with ultra-low latency audio pipeline ready\n"
            "• Automated Snapper Btrfs rollbacks enabled\n"
            "• macOS WhiteSur UI & Plank dock ready for login\n"
            "• Windows compatibility prefix isolated under /Applications/\n\n"
            "Please remove the installation USB or ISO drive before restarting."
        )
        tk.Label(c_inner, text=notes, font=("Segoe UI", 9), fg=Palette.TEXT_SECONDARY,
                 bg=Palette.BG_CARD, justify="left").pack(anchor="w", pady=(0, 20))

        btn_row = tk.Frame(c_inner, bg=Palette.BG_CARD)
        btn_row.pack(anchor="w")

        reboot_btn = ttk.Button(btn_row, text="Restart System Now", style="Primary.TButton",
                                command=self._on_reboot)
        reboot_btn.pack(side=tk.LEFT, padx=(0, 12))

        continue_btn = ttk.Button(btn_row, text="Continue in Live Session", style="Secondary.TButton",
                                  command=self._on_quit)
        continue_btn.pack(side=tk.LEFT)

    # ─── NAVIGATION CONTROLS ─────────────────────────────────────────────────
    def _on_next(self):
        if self.current_step == 1:
            # Validate disk
            if not self.config.target_disk:
                messagebox.showwarning("Selection Required", "Please select a target disk.")
                return
        elif self.current_step == 2:
            # Validate user account
            self.config.fullname = self.entry_fullname.get().strip()
            self.config.username = self.entry_username.get().strip()
            pw = self.entry_pw.get()
            confirm = self.entry_pw_confirm.get()
            ok_u, msg_u = Validation.validate_username(self.config.username)
            if not ok_u:
                messagebox.showwarning("Invalid Username", msg_u)
                return
            ok_p, msg_p = Validation.validate_passwords(pw, confirm)
            if not ok_p:
                messagebox.showwarning("Invalid Password", msg_p)
                return
            self.config.password = pw
            self.config.root_password = pw
            self.config.enable_auto_login = self.var_autologin.get()
        elif self.current_step == 3:
            # Save settings
            self.config.hostname = self.entry_hostname.get().strip()
            ok_h, msg_h = Validation.validate_hostname(self.config.hostname)
            if not ok_h:
                messagebox.showwarning("Invalid Hostname", msg_h)
                return
            self.config.timezone = self.tz_var.get()
            self.config.enable_wine_proton = self.var_proton.get()
            self.config.enable_zen_kernel = self.var_zen.get()
        elif self.current_step == 4:
            # Review to Install confirmation
            pass
        elif self.current_step == 6:
            self._on_reboot()
            return

        if self.current_step < len(self.step_names) - 1:
            self._show_step(self.current_step + 1)

    def _on_back(self):
        if 0 < self.current_step < 5:
            self._show_step(self.current_step - 1)

    def _on_quit(self):
        if self.current_step == 5:
            if not messagebox.askyesno("Quit Installer", "Installation is in progress. Are you sure you want to cancel?"):
                return
            if self.runner:
                self.runner.cancel()
        self.root.destroy()

    def _on_reboot(self):
        if self.dry_run or sys.platform == "win32":
            messagebox.showinfo("Reboot", "Dry run / Test mode: System would reboot now.")
            self.root.destroy()
        else:
            try:
                subprocess.run(["reboot"])
            except Exception:
                subprocess.run(["systemctl", "reboot"])
            self.root.destroy()

    def run(self):
        if not self.test_mode:
            self.root.mainloop()


def main():
    parser = argparse.ArgumentParser(description="Conjunction OS Graphical Installer")
    parser.add_argument("-d", "--dry-run", action="store_true", help="Run in simulation mode without writing to physical disks")
    parser.add_argument("--test-mode", action="store_true", help="Headless/test execution mode")
    args = parser.parse_args()

    app = ConjunctionInstallerApp(dry_run=args.dry_run, test_mode=args.test_mode)
    app.run()


if __name__ == "__main__":
    main()
