import pytest
from unittest.mock import patch, MagicMock
from pathlib import Path
import subprocess
from engine import _is_btrfs, _snapshot_subvolume, _restore_snapshot, _delete_directory_or_subvolume

@pytest.fixture
def mock_run_cmd():
    with patch("engine._run_cmd") as mock:
        yield mock

def test_is_btrfs_detection(mock_run_cmd):
    # Mocking stat to return btrfs
    mock_completed = MagicMock()
    mock_completed.stdout = "btrfs\n"
    mock_run_cmd.return_value = mock_completed
    
    path = Path("/some/path")
    assert _is_btrfs(path) is True
    mock_run_cmd.assert_called_with(["stat", "-f", "--format=%T", str(path)], check=False)
    
    # Mocking stat to return ext4
    mock_completed.stdout = "ext4\n"
    path2 = Path("/other/path")
    assert _is_btrfs(path2) is False

def test_snapshot_subvolume_success(mock_run_cmd):
    mock_run_cmd.return_value = MagicMock()
    
    src = Path("/src/prefix")
    dest = Path("/dest/snapshot")
    
    success = _snapshot_subvolume(src, dest)
    assert success is True
    mock_run_cmd.assert_called_once_with(["btrfs", "subvolume", "snapshot", str(src), str(dest)])

def test_snapshot_subvolume_failure(mock_run_cmd):
    mock_run_cmd.side_effect = Exception("btrfs error")
    
    success = _snapshot_subvolume(Path("/src"), Path("/dest"))
    assert success is False

def test_restore_snapshot_flow(mock_run_cmd, tmp_path):
    mock_run_cmd.return_value = MagicMock()
    
    snapshot = Path("/snapshots/pristine")
    dest = tmp_path / "app_prefix"
    dest.mkdir()
    
    # Mock _is_btrfs to return True so we test the subvolume deletion code path
    with patch("engine._is_btrfs", return_value=True):
        success = _restore_snapshot(snapshot, dest)
        
    assert success is True
    # Should call btrfs subvolume delete, then snapshot
    calls = [c[0][0] for c in mock_run_cmd.call_args_list]
    assert ["btrfs", "subvolume", "delete", str(dest)] in calls
    assert ["btrfs", "subvolume", "snapshot", str(snapshot), str(dest)] in calls

def test_delete_directory_or_subvolume_fallback(mock_run_cmd, tmp_path):
    mock_run_cmd.return_value = MagicMock()
    
    dest = tmp_path / "test_dir"
    dest.mkdir()
    
    # When not btrfs, should use shutil.rmtree
    with patch("engine._is_btrfs", return_value=False):
        _delete_directory_or_subvolume(dest)
        
    assert not dest.exists()
    mock_run_cmd.assert_not_called()
