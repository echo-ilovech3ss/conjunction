import pytest
from unittest.mock import patch, MagicMock
import argparse
from pathlib import Path
import tarfile
import os
import engine
from cli import ConjunctionCLI
from conftest import mock_run_cmd

@pytest.fixture
def mock_cli_dependencies():
    with patch("engine._which", side_effect=lambda name: f"/usr/bin/{name}"), \
         patch("engine._run_cmd", side_effect=mock_run_cmd) as mock_run, \
         patch("engine._is_btrfs", return_value=True):
        yield mock_run

def test_doctor_healthy(mock_cli_dependencies, capsys):
    args = argparse.Namespace(command="doctor", verbose=False, quiet=False, dry_run=False)
    cli_obj = ConjunctionCLI(args, "test-session")
    
    def mock_exists(self_path):
        if "pulse/native" in str(self_path).replace("\\", "/"):
            return True
        return os.path.exists(str(self_path))

    # Ensure directories are writeable in test and mock Unix socket existence
    with patch("os.access", return_value=True), \
         patch.object(Path, "exists", mock_exists):
        rc = cli_obj.run()
        
    assert rc == 0
    captured = capsys.readouterr()
    assert "Doctor Health Check" in captured.out
    assert "Wine Executable: Found" in captured.out or "Wine Executable" in captured.out
    assert "Winetricks Executable" in captured.out
    assert "Btrfs Filesystem" in captured.out
    assert "System is healthy!" in captured.out

def test_doctor_unhealthy(mock_cli_dependencies, capsys):
    args = argparse.Namespace(command="doctor", verbose=False, quiet=False, dry_run=False)
    
    # Mock no wine/proton and non-writeable dirs
    # We must instantiate ConjunctionCLI inside the patch block so it resolves paths during init
    with patch("engine._which", return_value=None), \
         patch("os.access", return_value=False):
        cli_obj = ConjunctionCLI(args, "test-session")
        rc = cli_obj.run()
        
    assert rc == 1
    captured = capsys.readouterr()
    assert "not found" in captured.out.lower()

def test_bug_report_generation(mock_cli_dependencies, tmp_path):
    report_file = tmp_path / "custom-report.tar.gz"
    args = argparse.Namespace(
        command="bug-report",
        verbose=False,
        quiet=False,
        dry_run=False,
        output_path=str(report_file)
    )
    
    # Write a dummy log file to package
    engine.LOG_DIR.mkdir(parents=True, exist_ok=True)
    (engine.LOG_DIR / "runner.log").write_text("Test runner log output")
    
    cli_obj = ConjunctionCLI(args, "test-session")
    rc = cli_obj.run()
    
    assert rc == 0
    assert report_file.exists()
    
    # Extract and verify tarball contents
    with tarfile.open(report_file, "r:gz") as tar:
        names = tar.getnames()
        # On some systems tar/tarfile prefix names with dot-slash
        has_diag = any("diagnostics.log" in name for name in names)
        has_log = any("runner.log" in name for name in names)
        assert has_diag
        assert has_log
        
        # Find exact name of diagnostics.log in the archive
        diag_name = [name for name in names if "diagnostics.log" in name][0]
        diag_member = tar.getmember(diag_name)
        f = tar.extractfile(diag_member)
        diag_content = f.read().decode("utf-8")
        assert "Conjunction OS Diagnostics" in diag_content
        assert "Environment Variables" in diag_content

def test_cleanup_command(mock_cli_dependencies, capsys):
    import time
    
    # Create test directories if not exists
    engine.LOG_DIR.mkdir(parents=True, exist_ok=True)
    engine.CRASH_DIR.mkdir(parents=True, exist_ok=True)
    engine.EXPORTS_DIR.mkdir(parents=True, exist_ok=True)
    engine.CACHE_DIR.mkdir(parents=True, exist_ok=True)
    
    # Create files
    old_log = engine.LOG_DIR / "stale_runner.log"
    old_log.write_text("Stale log")
    new_log = engine.LOG_DIR / "fresh_runner.log"
    new_log.write_text("Fresh log")
    
    # Backdate old file (10 days ago)
    past_time = time.time() - (10 * 24 * 3600)
    os.utime(old_log, (past_time, past_time))
    
    # Run cleanup subcommand
    args = argparse.Namespace(command="cleanup", days=7, verbose=False, quiet=False, dry_run=False)
    cli_obj = ConjunctionCLI(args, "test-session")
    rc = cli_obj.run()
    
    assert rc == 0
    
    # Verify old log deleted, fresh log preserved
    assert not old_log.exists()
    assert new_log.exists()
    
    captured = capsys.readouterr()
    assert "System Cleanup" in captured.out
    assert "Successfully cleaned" in captured.out

