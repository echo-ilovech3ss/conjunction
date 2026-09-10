"""
Automated Test Suite for Conjunction OS GUI Installer, Welcome Center, and God Logo.
Verifies vector SVG validity, PNG asset rendering across all resolutions,
backend hardware discovery, validation logic, asynchronous installation runner,
GUI page state transitions, and desktop entries.
"""

import os
import sys
import json
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
import pytest
from PIL import Image

import conjunction_gui
from conjunction_gui.logo import (
    CONJUNCTION_MARK_SVG,
    CONJUNCTION_APP_ICON_SVG,
    CONJUNCTION_BRANDED_BANNER_SVG,
    render_logo_png,
    export_all_brand_assets,
    install_system_icons,
)
from conjunction_gui.backend import (
    DiskInfo,
    SystemSpecs,
    InstallConfig,
    SystemDiscovery,
    Validation,
    InstallationRunner,
)
from conjunction_gui.theme import (
    Palette,
    apply_conjunction_theme,
    ModernCard,
    PartitionVisualBar,
    PasswordStrengthBar,
)


# ─── 1. GOD LOGO & BRAND ASSETS TESTS ────────────────────────────────────────

def test_god_logo_svg_validity():
    """Verify that all SVG assets are well-formed XML and contain required visual elements."""
    for name, svg_text in [
        ("mark", CONJUNCTION_MARK_SVG),
        ("app_icon", CONJUNCTION_APP_ICON_SVG),
        ("banner", CONJUNCTION_BRANDED_BANNER_SVG),
    ]:
        root = ET.fromstring(svg_text)
        assert root.tag.endswith("svg"), f"{name} root element must be <svg>"
        assert "viewBox" in root.attrib, f"{name} must specify a viewBox"
        # Verify definitions and gradients are present
        defs = root.find("{http://www.w3.org/2000/svg}defs")
        assert defs is not None, f"{name} must contain <defs> for gradients"


def test_god_logo_png_rendering_all_resolutions(tmp_path):
    """Verify PNG rasterization at all standard desktop icon sizes."""
    sizes = [16, 24, 32, 48, 64, 128, 256, 512]
    for sz in sizes:
        out_file = tmp_path / f"test-{sz}.png"
        ok = render_logo_png(str(out_file), size=sz, is_app_icon=True)
        assert ok is True
        assert out_file.exists()

        im = Image.open(str(out_file))
        assert im.size == (sz, sz), f"Size mismatch for {sz}x{sz}"
        assert im.mode == "RGBA", "Image must have RGBA alpha channel"

        # Verify image contains non-transparent pixels
        extrema = im.getextrema()
        assert extrema[3][1] > 0, "Image must not be completely transparent"


def test_export_and_install_system_icons(tmp_path):
    """Verify export_all_brand_assets and install_system_icons filesystem structure."""
    assets_dir = tmp_path / "assets"
    exported = export_all_brand_assets(str(assets_dir))
    assert Path(exported["svg_mark"]).exists()
    assert Path(exported["svg_logo"]).exists()
    assert Path(exported["svg_banner"]).exists()
    assert Path(exported["primary_png"]).exists()

    airootfs_dir = tmp_path / "airootfs"
    install_system_icons(str(airootfs_dir))

    # Verify standard icon paths
    assert (airootfs_dir / "usr/share/pixmaps/conjunction.png").exists()
    assert (airootfs_dir / "usr/share/pixmaps/conjunction-installer.png").exists()
    assert (airootfs_dir / "usr/share/icons/hicolor/scalable/apps/conjunction.svg").exists()
    assert (airootfs_dir / "usr/share/icons/hicolor/scalable/apps/conjunction-installer.svg").exists()
    for sz in [16, 32, 64, 128, 256, 512]:
        assert (airootfs_dir / f"usr/share/icons/hicolor/{sz}x{sz}/apps/conjunction.png").exists()
        assert (airootfs_dir / f"usr/share/icons/hicolor/{sz}x{sz}/apps/conjunction-installer.png").exists()


# ─── 2. BACKEND & VALIDATION TESTS ───────────────────────────────────────────

def test_system_specs_discovery():
    """Verify hardware discovery returns sane specifications."""
    specs = SystemDiscovery.get_system_specs()
    assert isinstance(specs, SystemSpecs)
    assert specs.ram_total_gb > 0.0
    assert len(specs.cpu_model) > 0
    assert isinstance(specs.is_uefi, bool)
    assert isinstance(specs.is_network_connected, bool)


def test_storage_devices_discovery():
    """Verify disk detection returns disk devices with valid properties."""
    disks = SystemDiscovery.get_available_disks()
    assert len(disks) >= 1
    for d in disks:
        assert isinstance(d, DiskInfo)
        assert d.name.strip() != ""
        assert d.path.startswith("/dev/")
        assert d.size_bytes > 0
        assert d.disk_type_label in ["NVMe SSD", "SATA SSD", "HDD"]


def test_validation_rules_username():
    """Test Linux username validation regex and reserved names."""
    valid_names = ["user", "conjunction", "dev_1", "arch-user", "_test"]
    for u in valid_names:
        ok, msg = Validation.validate_username(u)
        assert ok is True, f"Expected '{u}' to be valid, got: {msg}"

    invalid_names = ["", "Root", "123user", "bad name", "user@host", "root", "daemon", "a" * 35]
    for u in invalid_names:
        ok, _ = Validation.validate_username(u)
        assert ok is False, f"Expected '{u}' to be invalid"


def test_validation_rules_passwords():
    """Test password matching, character rules, and strength calculation."""
    # Empty
    ok, _ = Validation.validate_passwords("", "")
    assert ok is False

    # Colon character forbidden (breaks Linux chpasswd field separation)
    ok, msg = Validation.validate_passwords("pass:word", "pass:word")
    assert ok is False
    assert "colon" in msg.lower()

    # Mismatch
    ok, _ = Validation.validate_passwords("mypassword", "otherpassword")
    assert ok is False

    # Valid
    ok, _ = Validation.validate_passwords("correct-horse-battery", "correct-horse-battery")
    assert ok is True

    # Strength scores
    assert Validation.calculate_password_strength("") == 0
    assert Validation.calculate_password_strength("123") == 1
    assert Validation.calculate_password_strength("simplepass") >= 2
    assert Validation.calculate_password_strength("StrongPass99!") >= 3
    assert Validation.calculate_password_strength("C0smic-Conjunction-2026!") == 4


def test_validation_rules_hostname():
    """Test RFC hostname validation."""
    assert Validation.validate_hostname("conjunction")[0] is True
    assert Validation.validate_hostname("arch-box-1")[0] is True
    assert Validation.validate_hostname("")[0] is False
    assert Validation.validate_hostname("-invalid")[0] is False
    assert Validation.validate_hostname("invalid-")[0] is False
    assert Validation.validate_hostname("bad_hostname")[0] is False


def test_installation_runner_pipeline(tmp_path):
    """Test the asynchronous installation runner orchestrates all 11 steps in dry-run mode."""
    state_file = tmp_path / "install-state.json"
    cfg = InstallConfig(
        target_disk="sda",
        part_scheme=1,
        part_method=1,
        username="testrunner",
        fullname="Test Runner",
        password="testpassword",
        hostname="conjunction-test",
        timezone="UTC",
        is_dry_run=True
    )

    progress_events = []
    completion_result = []

    def on_progress(step_curr, step_tot, step_name, pct, log_line):
        progress_events.append((step_curr, step_tot, step_name, pct, log_line))

    def on_complete(success, err):
        completion_result.append((success, err))

    runner = InstallationRunner(config=cfg, on_progress=on_progress, on_complete=on_complete)
    runner.state_file = state_file

    # Run directly in this thread for test determinism
    runner._run()

    assert len(completion_result) == 1
    assert completion_result[0][0] is True, f"Install failed with: {completion_result[0][1]}"
    assert len(progress_events) >= 11

    # Verify state checkpoint was recorded
    assert state_file.exists()
    state_data = json.loads(state_file.read_text(encoding="utf-8"))
    assert "completed_steps" in state_data
    assert "partitioning" in state_data["completed_steps"]
    assert "subvolumes" in state_data["completed_steps"]
    assert "bootloader" in state_data["completed_steps"]
    assert state_data["target_disk"] == "sda"


# ─── 3. GUI STATE & PAGE NAVIGATION TESTS ───────────────────────────────────

@pytest.fixture(scope="module")
def tk_root():
    """Provides a shared hidden Tk root to prevent Tcl teardown issues in test runs."""
    import tkinter as tk
    root = tk.Tk()
    root.withdraw()
    yield root
    try:
        root.destroy()
    except Exception:
        pass


def test_installer_gui_instantiation_and_step_transitions(tk_root):
    """Verify GUI installer initializes cleanly and transitions through all 7 pages."""
    import tkinter as tk
    from conjunction_gui.installer import ConjunctionInstallerApp

    for child in tk_root.winfo_children():
        child.destroy()

    app = ConjunctionInstallerApp(root=tk_root, dry_run=True, test_mode=True)
    assert app.current_step == 0
    assert len(app.step_names) == 7

    # Step 0: Welcome
    assert str(app.btn_back.cget("state")) == "disabled"
    assert str(app.btn_next.cget("text")) == "Next"

    # Step 1: Storage
    app._show_step(1)
    assert app.current_step == 1
    assert len(app.disk_card_widgets) > 0
    assert str(app.btn_back.cget("state")) == "normal"

    # Step 2: User Account
    app._show_step(2)
    assert app.current_step == 2
    assert hasattr(app, "entry_username")
    assert hasattr(app, "entry_pw")
    # Enter valid user info
    app.entry_username.delete(0, tk.END)
    app.entry_username.insert(0, "archtest")
    app.entry_pw.delete(0, tk.END)
    app.entry_pw.insert(0, "validpass123")
    app.entry_pw_confirm.delete(0, tk.END)
    app.entry_pw_confirm.insert(0, "validpass123")
    app._on_pw_change()

    # Step 3: Preferences
    app._show_step(3)
    assert app.current_step == 3
    assert hasattr(app, "entry_hostname")

    # Step 4: Summary
    app._show_step(4)
    assert app.current_step == 4
    assert str(app.btn_next.cget("text")) == "Install Conjunction OS"

    # Step 5: Installing
    app._show_step(5)
    assert app.current_step == 5
    assert str(app.btn_back.cget("state")) == "disabled"

    # Step 6: Completed
    app._show_step(6)
    assert app.current_step == 6
    assert str(app.btn_next.cget("text")) == "Reboot Now"

    # Test back navigation
    app._show_step(3)
    app._on_back()
    assert app.current_step == 2


def test_welcome_gui_instantiation(tk_root):
    """Verify Welcome Hub application initializes with action cards and system specs."""
    from conjunction_gui.welcome import ConjunctionWelcomeApp

    for child in tk_root.winfo_children():
        child.destroy()

    app = ConjunctionWelcomeApp(root=tk_root, test_mode=True)
    assert app.specs is not None
    assert app.specs.ram_total_gb > 0.0


# ─── 4. DESKTOP ENTRIES & LAUNCHER SCRIPTS INTEGRATION ───────────────────────

def test_desktop_entries_syntax_and_executables():
    """Verify desktop entries in airootfs are valid INI files with correct keys and targets."""
    project_root = Path(__file__).parent.parent
    desktop_files = [
        project_root / "archiso/airootfs/usr/share/applications/conjunction-install.desktop",
        project_root / "archiso/airootfs/usr/share/applications/conjunction-welcome.desktop",
        project_root / "archiso/airootfs/etc/skel/Desktop/conjunction-install.desktop",
        project_root / "archiso/airootfs/etc/xdg/autostart/conjunction-welcome.desktop",
    ]

    for df in desktop_files:
        assert df.exists(), f"Desktop file missing: {df}"
        content = df.read_text(encoding="utf-8")
        assert "[Desktop Entry]" in content
        assert "Type=Application" in content
        assert "Exec=" in content
        assert "Icon=" in content

        # Check that Exec refers to an existing launcher script or binary
        for line in content.splitlines():
            if line.startswith("Exec="):
                exec_target = line.split("=", 1)[1].split()[0]
                # Map /usr/local/bin to repo's airootfs/usr/local/bin
                if exec_target.startswith("/usr/local/bin/"):
                    rel_name = exec_target.replace("/usr/local/bin/", "")
                    local_bin = project_root / "archiso/airootfs/usr/local/bin" / rel_name
                    assert local_bin.exists(), f"Exec binary missing: {local_bin}"
            elif line.startswith("Icon="):
                icon_name = line.split("=", 1)[1].strip()
                # Verify icon asset exists in icons or pixmaps
                icon_png = project_root / f"archiso/airootfs/usr/share/pixmaps/{icon_name}.png"
                icon_svg = project_root / f"archiso/airootfs/usr/share/icons/hicolor/scalable/apps/{icon_name}.svg"
                assert icon_png.exists() or icon_svg.exists(), f"Icon asset missing for: {icon_name}"


def test_validation_disk_size():
    """Test storage size boundary validation (minimum 20 GB)."""
    ok, err = Validation.validate_disk_size(10 * (1024**3))
    assert ok is False
    assert "20.0 GB" in err

    ok, err = Validation.validate_disk_size(19 * (1024**3))
    assert ok is False

    ok, err = Validation.validate_disk_size(20 * (1024**3))
    assert ok is True
    assert err == ""

    ok, err = Validation.validate_disk_size(512 * (1024**3))
    assert ok is True


def test_disk_selection_reactivity(tk_root):
    """Verify GUI disk selection properly updates radio symbol and selected disk variable."""
    from conjunction_gui.installer import ConjunctionInstallerApp

    for child in tk_root.winfo_children():
        child.destroy()

    app = ConjunctionInstallerApp(root=tk_root, dry_run=True, test_mode=True)
    app._show_step(1)
    assert len(app.available_disks) >= 2

    first_disk = app.available_disks[0].name
    second_disk = app.available_disks[1].name

    # Initial selection is first disk
    assert app.config.target_disk == first_disk
    first_item = next(it for it in app.disk_card_items if it["disk"].name == first_disk)
    second_item = next(it for it in app.disk_card_items if it["disk"].name == second_disk)
    assert first_item["rad_lbl"].cget("text") == "◉"

    # Select second disk
    app._select_disk(second_disk)
    assert app.config.target_disk == second_disk
    assert first_item["rad_lbl"].cget("text") == "○"
    assert second_item["rad_lbl"].cget("text") == "◉"


def test_partitioning_method_selection(tk_root):
    """Verify GUI partitioning method switches between automatic and manual."""
    from conjunction_gui.installer import ConjunctionInstallerApp

    for child in tk_root.winfo_children():
        child.destroy()

    app = ConjunctionInstallerApp(root=tk_root, dry_run=True, test_mode=True)
    app._show_step(1)
    assert hasattr(app, "var_part_method")
    assert app.var_part_method.get() == 1  # Automatic default

    app.var_part_method.set(2)  # Manual
    app._on_part_method_change()
    assert app.config.part_method == 2

    # Check launch partition manager button exists
    assert hasattr(app, "btn_open_partman")


def test_installation_runner_unattended_config_writing(tmp_path):
    """Verify InstallationRunner writes unattended JSON config before execution."""
    cfg = InstallConfig(
        target_disk="nvme0n1",
        part_scheme=1,
        part_method=1,
        username="unattended_user",
        fullname="Unattended Test",
        password="secretpassword",
        hostname="custom-box",
        timezone="America/New_York",
        enable_snapper=True,
        is_dry_run=True,
    )

    runner = InstallationRunner(config=cfg)
    cfg_file = tmp_path / "test-unattended.json"
    runner._write_unattended_config(cfg_file)

    assert cfg_file.exists()
    payload = json.loads(cfg_file.read_text(encoding="utf-8"))
    assert payload["target_disk"] == "nvme0n1"
    assert payload["username"] == "unattended_user"
    assert payload["hostname"] == "custom-box"
    assert payload["timezone"] == "America/New_York"
    assert payload["enable_snapper"] is True

