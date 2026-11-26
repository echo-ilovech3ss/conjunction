import argparse
import os
import sys
from pathlib import Path
from unittest.mock import patch

_repo_root = Path(__file__).resolve().parent.parent
if str(_repo_root) not in sys.path:
    sys.path.insert(0, str(_repo_root))

import engine
from cli import ConjunctionCLI


def test_install_and_remove_self_contained_wine_bundle(tmp_path, monkeypatch):
    apps_dir = tmp_path / "Applications"
    apps_dir.mkdir()
    monkeypatch.setenv("CONJUNCTION_USER_APPS_DIR", str(apps_dir))

    exe_path = tmp_path / "MiniPad.exe"
    exe_path.write_bytes(b"MZ_TEST_PE")

    api = engine.ConjunctionAPI()
    api.wine_path = "/usr/bin/wine"
    api.proton_path = None

    with patch("engine._run_cmd") as mock_cmd:
        mock_cmd.return_value = engine.subprocess.CompletedProcess([], 0, "", "")
        meta = api.install_bundle(str(exe_path), app_name="MiniPad")

    bundle = Path(meta["bundle_path"])
    assert bundle == apps_dir / "MiniPad.app"
    assert (bundle / "Contents" / "Info.toml").is_file()
    assert (bundle / "Contents" / "WinePrefix").is_dir()
    assert (bundle / "Contents" / "WinePrefix" / "drive_c" / "Program Files" / "MiniPad" / "MiniPad.exe").is_file()
    assert (bundle / "Contents" / "MacOS" / "MiniPad").is_file()
    assert os.access(bundle / "Contents" / "MacOS" / "MiniPad", os.X_OK)

    # Confirm nothing leaked into ~/.conjunction/prefixes
    assert not (engine.PREFIX_DIR / "MiniPad").exists()

    # Validate Info.toml content
    info_text = (bundle / "Contents" / "Info.toml").read_text(encoding="utf-8")
    assert 'bundle_format = "conjunction.app/2"' in info_text
    assert 'runtime = "wine"' in info_text
    assert 'prefix = "Contents/WinePrefix"' in info_text

    # Test running from bundle (creating dummy Wine reg files for prefix validation)
    prefix = bundle / "Contents" / "WinePrefix"
    (prefix / "user.reg").write_text("", encoding="utf-8")
    (prefix / "system.reg").write_text("", encoding="utf-8")

    with patch("engine.subprocess.Popen") as mock_popen:
        mock_popen.return_value.wait.return_value = 0
        rc = api.run_bundle(bundle)
    assert rc == 0
    called_cmd, called_kwargs = mock_popen.call_args[0][0], mock_popen.call_args[1]
    assert str(prefix) == called_kwargs["env"]["WINEPREFIX"]
    assert "MiniPad.exe" in called_cmd[1]

    # Deleting the bundle deletes the entire Windows install
    api.remove_bundle("MiniPad")
    assert not bundle.exists()
    assert not prefix.exists()


def test_cli_install_exe_and_apps_remove_bundle(tmp_path, monkeypatch):
    apps_dir = tmp_path / "Applications"
    apps_dir.mkdir()
    monkeypatch.setenv("CONJUNCTION_USER_APPS_DIR", str(apps_dir))

    exe_path = tmp_path / "CalcWin.exe"
    exe_path.write_bytes(b"MZ_CALC")

    args = argparse.Namespace(
        command="install",
        app_name_or_path=str(exe_path),
        force=False,
        sandbox=False,
        verbose=False,
        quiet=True,
        dry_run=False,
    )
    with patch("engine._run_cmd") as mock_cmd:
        mock_cmd.return_value = engine.subprocess.CompletedProcess([], 0, "", "")
        cli_obj = ConjunctionCLI(args, "test-wine-bundle")
        rc = cli_obj.run()

    assert rc == 0
    bundle = apps_dir / "CalcWin.app"
    assert bundle.is_dir()
    assert (bundle / "Contents" / "WinePrefix").is_dir()

    remove_args = argparse.Namespace(
        command="apps",
        remove="CalcWin",
        verbose=False,
        quiet=True,
        dry_run=False,
    )
    with patch("cli._confirm", return_value=True):
        cli_rm = ConjunctionCLI(remove_args, "test-wine-remove")
        rc_rm = cli_rm.run()

    assert rc_rm == 0
    assert not bundle.exists()
