"""
Theme, Palette, and Custom Styled Widgets for Conjunction OS GUI.
Emulates the sleek, modern aesthetic of Fedora Anaconda / GNOME WebUI / WhiteSur.
"""

import tkinter as tk
from tkinter import ttk
from typing import Optional, Callable, Dict, Any, Tuple

# Modern Fedora / WhiteSur Deep Slate Theme Colors
class Palette:
    # Surfaces & Backgrounds
    BG_DARK = "#0e131d"         # Deep Space Navy
    BG_SIDEBAR = "#141a26"      # Sidebar & Stepper background
    BG_CARD = "#1a2232"         # Elevated Card Surface
    BG_CARD_HOVER = "#222c40"   # Hover Card Surface
    BG_CARD_SELECTED = "#1c2b45"# Selected Card Surface
    BG_INPUT = "#131a27"        # Text entry background
    BG_PROGRESS_TRACK = "#1e293b"# Progress Bar Track

    # Borders & Lines
    BORDER_DEFAULT = "#26334a"  # Subtle separator
    BORDER_FOCUSED = "#00f2fe"  # Active focus border
    BORDER_SELECTED = "#38bdf8" # Selected element border
    BORDER_MUTED = "#1e293b"

    # Typography Colors
    TEXT_PRIMARY = "#f8fafc"    # High-contrast crisp white
    TEXT_SECONDARY = "#94a3b8"  # Balanced slate for labels/descriptions
    TEXT_MUTED = "#64748b"      # Hints and disabled text
    TEXT_ACCENT = "#38bdf8"     # Bright cyan-blue for highlighted labels

    # Brand Accents (Celestial / Conjunction Palette)
    ACCENT_CYAN = "#00f2fe"     # Electric Cyan (Primary highlight)
    ACCENT_BLUE = "#3b82f6"     # Fedora / Cosmic Blue (Primary buttons)
    ACCENT_BLUE_HOVER = "#2563eb"
    ACCENT_PURPLE = "#7928ca"   # Nebula Purple
    ACCENT_EMERALD = "#10b981"  # Success Green
    ACCENT_AMBER = "#f59e0b"    # Warning
    ACCENT_CRIMSON = "#ef4444"  # Danger / Disk wipe alert

    # Partition Visualization Colors
    PART_EFI = "#3b82f6"        # EFI System
    PART_ROOT = "#00f2fe"       # Btrfs Root @
    PART_HOME = "#10b981"       # Btrfs @home
    PART_SNAPSHOTS = "#a855f7"  # Btrfs @snapshots
    PART_FREE = "#334155"       # Free Space


def apply_conjunction_theme(root: tk.Tk) -> ttk.Style:
    """Applies modern dark-slate theme styles to ttk widgets."""
    style = ttk.Style(root)
    try:
        style.theme_use("clam")
    except Exception:
        pass

    # Global widget styles
    style.configure(".",
        background=Palette.BG_DARK,
        foreground=Palette.TEXT_PRIMARY,
        fieldbackground=Palette.BG_INPUT,
        troughcolor=Palette.BG_PROGRESS_TRACK,
        font=("Segoe UI", 10)
    )

    # Frame styles
    style.configure("TFrame", background=Palette.BG_DARK)
    style.configure("Sidebar.TFrame", background=Palette.BG_SIDEBAR)
    style.configure("Card.TFrame", background=Palette.BG_CARD)

    # Label styles
    style.configure("TLabel", background=Palette.BG_DARK, foreground=Palette.TEXT_PRIMARY)
    style.configure("Sidebar.TLabel", background=Palette.BG_SIDEBAR, foreground=Palette.TEXT_SECONDARY)
    style.configure("Card.TLabel", background=Palette.BG_CARD, foreground=Palette.TEXT_PRIMARY)
    style.configure("Header.TLabel",
        font=("Segoe UI", 16, "bold"),
        foreground=Palette.TEXT_PRIMARY,
        background=Palette.BG_DARK
    )
    style.configure("Subheader.TLabel",
        font=("Segoe UI", 10),
        foreground=Palette.TEXT_SECONDARY,
        background=Palette.BG_DARK
    )

    # Buttons
    style.configure("Primary.TButton",
        background=Palette.ACCENT_BLUE,
        foreground="#ffffff",
        font=("Segoe UI", 10, "bold"),
        borderwidth=0,
        focuscolor=Palette.ACCENT_CYAN,
        padding=(18, 9)
    )
    style.map("Primary.TButton",
        background=[("active", Palette.ACCENT_BLUE_HOVER), ("disabled", Palette.BG_CARD)],
        foreground=[("disabled", Palette.TEXT_MUTED)]
    )

    style.configure("Secondary.TButton",
        background=Palette.BG_CARD,
        foreground=Palette.TEXT_PRIMARY,
        font=("Segoe UI", 10),
        borderwidth=1,
        relief="solid",
        padding=(14, 8)
    )
    style.map("Secondary.TButton",
        background=[("active", Palette.BG_CARD_HOVER), ("disabled", Palette.BG_DARK)],
        foreground=[("disabled", Palette.TEXT_MUTED)]
    )

    style.configure("Danger.TButton",
        background=Palette.ACCENT_CRIMSON,
        foreground="#ffffff",
        font=("Segoe UI", 10, "bold"),
        borderwidth=0,
        padding=(16, 8)
    )
    style.map("Danger.TButton",
        background=[("active", "#dc2626"), ("disabled", Palette.BG_CARD)],
        foreground=[("disabled", Palette.TEXT_MUTED)]
    )

    # Entry fields
    style.configure("TEntry",
        fieldbackground=Palette.BG_INPUT,
        foreground=Palette.TEXT_PRIMARY,
        insertcolor=Palette.ACCENT_CYAN,
        borderwidth=1,
        relief="solid",
        padding=6
    )

    # Checkbuttons & Radiobuttons
    style.configure("TCheckbutton",
        background=Palette.BG_DARK,
        foreground=Palette.TEXT_PRIMARY,
        font=("Segoe UI", 10)
    )
    style.configure("Card.TCheckbutton",
        background=Palette.BG_CARD,
        foreground=Palette.TEXT_PRIMARY,
        font=("Segoe UI", 10)
    )
    style.configure("TRadiobutton",
        background=Palette.BG_DARK,
        foreground=Palette.TEXT_PRIMARY,
        font=("Segoe UI", 10)
    )
    style.configure("Card.TRadiobutton",
        background=Palette.BG_CARD,
        foreground=Palette.TEXT_PRIMARY,
        font=("Segoe UI", 10)
    )

    # Progress bar
    style.configure("TProgressbar",
        background=Palette.ACCENT_CYAN,
        troughcolor=Palette.BG_PROGRESS_TRACK,
        borderwidth=0,
        thickness=8
    )

    return style


class ModernCard(tk.Canvas):
    """
    Rounded modern card canvas that can contain other widgets or custom drawing.
    Emulates modern GNOME Adwaita / Fedora cards.
    """
    def __init__(self, parent, bg=Palette.BG_CARD, border=Palette.BORDER_DEFAULT,
                 radius=10, highlight_border=Palette.BORDER_SELECTED, **kwargs):
        parent_bg = Palette.BG_DARK
        try:
            parent_bg = parent.cget("bg")
        except Exception:
            pass
        super().__init__(parent, bg=parent_bg, highlightthickness=0, **kwargs)
        self.card_bg = bg
        self.card_border = border
        self.highlight_border = highlight_border
        self.radius = radius
        self.is_selected = False
        self.bind("<Configure>", self._on_resize)

    def set_selected(self, selected: bool):
        self.is_selected = selected
        self._redraw()

    def _on_resize(self, event):
        self._redraw()

    def _redraw(self):
        self.delete("card_bg")
        w = self.winfo_width()
        h = self.winfo_height()
        if w <= 1 or h <= 1:
            return

        r = self.radius
        border_col = self.highlight_border if self.is_selected else self.card_border
        fill_col = Palette.BG_CARD_SELECTED if self.is_selected else self.card_bg
        lw = 2 if self.is_selected else 1

        # Rounded polygon coordinates
        pts = [
            r, 1,
            w - r, 1,
            w - 1, 1,
            w - 1, r,
            w - 1, h - r,
            w - 1, h - 1,
            w - r, h - 1,
            r, h - 1,
            1, h - 1,
            1, h - r,
            1, r,
            1, 1
        ]
        self.create_polygon(pts, fill=fill_col, outline=border_col, width=lw,
                            smooth=True, tags="card_bg")
        self.tag_lower("card_bg")


class PartitionVisualBar(tk.Canvas):
    """
    Visual color-coded horizontal storage distribution bar.
    Shows EFI, Btrfs subvolumes (@, @home, @snapshots), and free space.
    """
    def __init__(self, parent, height=20, **kwargs):
        super().__init__(parent, height=height, bg=Palette.BG_CARD,
                         highlightthickness=0, **kwargs)
        self.segments = [
            ("EFI (512MB)", 0.08, Palette.PART_EFI),
            ("Root / (@)", 0.42, Palette.PART_ROOT),
            ("Home (@home)", 0.35, Palette.PART_HOME),
            ("Snapshots (@snapshots)", 0.15, Palette.PART_SNAPSHOTS),
        ]
        self.bind("<Configure>", lambda e: self.draw())

    def set_segments(self, segments):
        self.segments = segments
        self.draw()

    def draw(self):
        self.delete("all")
        w = self.winfo_width()
        h = self.winfo_height()
        if w < 10 or h < 5:
            return

        x = 0
        r = 4
        # Draw background track
        self.create_rectangle(0, 0, w, h, fill=Palette.BG_PROGRESS_TRACK, width=0)

        for label, fraction, color in self.segments:
            seg_w = max(4, int(w * fraction))
            self.create_rectangle(x, 0, min(w, x + seg_w), h, fill=color, width=0)
            # Add faint divider line
            if x + seg_w < w:
                self.create_line(x + seg_w, 0, x + seg_w, h, fill=Palette.BG_CARD, width=1)
            x += seg_w


class PasswordStrengthBar(tk.Canvas):
    """
    Interactive color-coded password strength meter bar.
    """
    def __init__(self, parent, height=6, **kwargs):
        super().__init__(parent, height=height, bg=Palette.BG_DARK,
                         highlightthickness=0, **kwargs)
        self.score = 0  # 0 to 4
        self.bind("<Configure>", lambda e: self.draw())

    def set_strength(self, score: int):
        self.score = max(0, min(4, score))
        self.draw()

    def draw(self):
        self.delete("all")
        w = self.winfo_width()
        h = self.winfo_height()
        if w < 10:
            return

        colors = [
            Palette.BG_PROGRESS_TRACK, # 0
            Palette.ACCENT_CRIMSON,     # 1: Weak
            Palette.ACCENT_AMBER,       # 2: Fair
            "#38bdf8",                  # 3: Good
            Palette.ACCENT_EMERALD      # 4: Strong
        ]
        col = colors[self.score]

        # Draw 4 segments
        gap = 4
        seg_w = (w - 3 * gap) / 4.0
        for i in range(4):
            x1 = int(i * (seg_w + gap))
            x2 = int(x1 + seg_w)
            fill = col if i < self.score else Palette.BG_PROGRESS_TRACK
            self.create_rectangle(x1, 0, x2, h, fill=fill, width=0)
