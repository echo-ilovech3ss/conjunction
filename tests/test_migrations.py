import pytest
import json
import tarfile
import engine
from pathlib import Path
from unittest.mock import patch, MagicMock
from engine import ConjunctionAPI, CURRENT_SCHEMA_VERSION

def test_prefix_metadata_schema_migration(tmp_path):
    api = ConjunctionAPI()
    app_name = "migapp"
    prefix_path = engine.PREFIX_DIR / app_name
    prefix_path.mkdir(parents=True)
    
    # 1. Create a version 1 metadata file
    meta_file = prefix_path / ".conjunction_meta.json"
    meta_v1 = {
        "schema_version": 1,
        "app_name": app_name,
        "created_at": "2026-06-25T12:00:00"
    }
    with open(meta_file, "w", encoding="utf-8") as f:
        json.dump(meta_v1, f)
        
    # Mock _create_desktop_entry to avoid creating real desktop launcher in test
    with patch.object(api, "_create_desktop_entry") as mock_create_desktop:
        api._migrate_prefix_metadata(prefix_path, app_name)
        
    # Verify version has been migrated to CURRENT_SCHEMA_VERSION (2)
    with open(meta_file, "r", encoding="utf-8") as f:
        migrated = json.load(f)
        
    assert migrated["schema_version"] == CURRENT_SCHEMA_VERSION
    assert "migrated_from_v1_at" in migrated
    mock_create_desktop.assert_called_once_with(app_name, prefix_path)

def test_import_archive_format_migration(tmp_path):
    api = ConjunctionAPI()
    app_name = "migratearchiveapp"
    
    # 1. Create a v1 archive (app.manifest + wineprefix directory)
    archive_path = tmp_path / "v1_archive.tar.gz"
    src_dir = tmp_path / "v1_src"
    src_dir.mkdir()
    
    v1_manifest = {
        "name": app_name,
        "prefix_path": "/old/path/wineprefix",
        "primary_exe": "/old/path/wineprefix/app.exe",
        "archive_version": 1
    }
    with open(src_dir / "app.manifest", "w", encoding="utf-8") as f:
        json.dump(v1_manifest, f)
        
    wineprefix_dir = src_dir / "wineprefix"
    wineprefix_dir.mkdir()
    (wineprefix_dir / "app.exe").touch()
    
    with tarfile.open(archive_path, "w:gz") as tar:
        tar.add(src_dir / "app.manifest", arcname="app.manifest")
        tar.add(wineprefix_dir, arcname="wineprefix")
        
    # Mock desktop entry recreation
    with patch.object(api, "_create_desktop_entry"):
        metadata = api.import_app(archive_path)
        
    # Verify final imported metadata
    assert metadata["name"] == app_name
    assert metadata["archive_version"] == 2
    assert metadata["schema_version"] == CURRENT_SCHEMA_VERSION
    assert Path(metadata["prefix_path"]) == engine.PREFIX_DIR / app_name
    assert (engine.PREFIX_DIR / app_name / "app.exe").exists()
