"""
Conjunction OS GUI Suite
Modern Fedora-style Graphical Installer, Welcome Setup Application, and Brand System.
"""

import os
import sys

# Ensure Tk/Tcl libraries can be resolved reliably across all environments
if sys.platform == "win32":
    tcl_cand = os.path.join(sys.prefix, "tcl", "tcl8.6")
    tk_cand = os.path.join(sys.prefix, "tcl", "tk8.6")
    if os.path.isdir(tcl_cand) and "TCL_LIBRARY" not in os.environ:
        os.environ["TCL_LIBRARY"] = tcl_cand
    if os.path.isdir(tk_cand) and "TK_LIBRARY" not in os.environ:
        os.environ["TK_LIBRARY"] = tk_cand

__version__ = "1.0.0"
__author__ = "Conjunction OS Project"

from .logo import (
    CONJUNCTION_MARK_SVG,
    CONJUNCTION_APP_ICON_SVG,
    CONJUNCTION_BRANDED_BANNER_SVG,
    render_logo_png,
    export_all_brand_assets,
    install_system_icons,
)
