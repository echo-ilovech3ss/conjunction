import pytest
from unittest.mock import patch, MagicMock
from pathlib import Path
import json
import engine
from engine import ConjunctionAPI, PrefixError, AppNotFoundError

@pytest.fixture
def mock_engine_helpers():
    with patch("engine._run_cmd") as mock_run_cmd, \
         patch("engine._which", return_value="/usr/bin/wine") as mock_which, \
         patch("engine._is_btrfs", return_value=False) as mock_is_btrfs:
        yield mock_run_cmd, mock_which, mock_is_btrfs

def test_prefix_creation(mock_engine_helpers):
    mock_run_cmd, _, _ = mock_engine_helpers
    
    api = ConjunctionAPI()
    app_name = "mytestapp"
    
    # Run creation
    prefix_path = api._create_prefix(app_name)
    
    # Assert correct path is returned and exists
    assert prefix_path == engine.PREFIX_DIR / app_name
    assert prefix_path.exists()
    
    # Assert wineboot --init command was run
    mock_run_cmd.assert_called_once()
    args, kwargs = mock_run_cmd.call_args
    assert "wineboot" in args[0]
    assert "--init" in args[0]
    assert kwargs["env"]["WINEPREFIX"] == str(prefix_path)

def test_prefix_configuration(mock_engine_helpers, tmp_path):
    api = ConjunctionAPI()
    app_name = "configtestapp"
    
    # Setup dummy metadata so configure works
    metadata = {
        "name": app_name,
        "prefix_path": str(engine.PREFIX_DIR / app_name),
        "primary_exe": "dummy.exe"
    }
    api._create_prefix(app_name)
    with open(engine.APPS_DIR / f"{app_name}.json", "w", encoding="utf-8") as f:
        json.dump(metadata, f)
        
    # Configure custom parameters
    updated = api.configure(
        app_name,
        dxvk_hud="fps,gpuload",
        esync=True,
        fsync=False,
        wine_debug="+dll"
    )
    
    # Assert metadata is updated
    assert updated["config"]["dxvk_hud"] == "fps,gpuload"
    assert updated["config"]["esync"] is True
    assert updated["config"]["fsync"] is False
    assert updated["config"]["wine_debug"] == "+dll"
    
    # Assert changes are persisted
    with open(engine.APPS_DIR / f"{app_name}.json", "r", encoding="utf-8") as f:
        saved = json.load(f)
    assert saved["config"]["dxvk_hud"] == "fps,gpuload"

def test_prefix_deletion(mock_engine_helpers):
    api = ConjunctionAPI()
    app_name = "deletetestapp"
    
    # Create prefix and metadata
    prefix_path = api._create_prefix(app_name)
    meta_file = engine.APPS_DIR / f"{app_name}.json"
    metadata = {
        "name": app_name,
        "prefix_path": str(prefix_path),
        "primary_exe": "dummy.exe"
    }
    with open(meta_file, "w", encoding="utf-8") as f:
        json.dump(metadata, f)
        
    # Create dummy desktop file
    desktop_file = engine.DESKTOP_DIR / f"conjunction-{app_name}.desktop"
    desktop_file.touch()
    
    # Perform removal
    api.remove(app_name)
    
    # Verify everything is deleted
    assert not prefix_path.exists()
    assert not meta_file.exists()
    assert not desktop_file.exists()
