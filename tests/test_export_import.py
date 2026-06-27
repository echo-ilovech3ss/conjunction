import pytest
import tarfile
import json
import shutil
import engine
from pathlib import Path
from unittest.mock import patch, MagicMock
from engine import ConjunctionAPI, AppNotFoundError, PrefixError

def test_export_app_success(tmp_path):
    api = ConjunctionAPI()
    app_name = "exportapp"
    
    # 1. Create a dummy prefix and metadata
    prefix_path = engine.PREFIX_DIR / app_name
    prefix_path.mkdir(parents=True)
    (prefix_path / "dummy_file.txt").write_text("Hello Wine")
    
    metadata = {
        "name": app_name,
        "prefix_path": str(prefix_path),
        "primary_exe": str(prefix_path / "dummy_file.txt")
    }
    with open(engine.APPS_DIR / f"{app_name}.json", "w", encoding="utf-8") as f:
        json.dump(metadata, f)
        
    archive_path = tmp_path / "exportapp.tar.gz"
    
    # Run export
    api.export_app(app_name, archive_path)
    
    # Verify archive exists
    assert archive_path.exists()
    
    # Inspect archive contents
    with tarfile.open(archive_path, "r:gz") as tar:
        names = tar.getnames()
        assert "manifest.json" in names
        assert "prefix/dummy_file.txt" in names
        
        # Read manifest
        member = tar.getmember("manifest.json")
        f = tar.extractfile(member)
        manifest = json.loads(f.read().decode("utf-8"))
        assert manifest["name"] == app_name
        assert manifest["archive_version"] == 2
        assert manifest["schema_version"] == 2

def test_import_app_success(tmp_path):
    api = ConjunctionAPI()
    app_name = "importapp"
    
    # 1. Manually build a valid export tarball
    archive_path = tmp_path / "importapp.tar.gz"
    src_dir = tmp_path / "archive_src"
    src_dir.mkdir()
    
    manifest = {
        "name": app_name,
        "prefix_path": "/old/path/prefixes/importapp",
        "primary_exe": "/old/path/prefixes/importapp/game.exe",
        "archive_version": 2,
        "schema_version": 2
    }
    with open(src_dir / "manifest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f)
        
    prefix_src = src_dir / "prefix"
    prefix_src.mkdir()
    (prefix_src / "game.exe").touch()
    
    with tarfile.open(archive_path, "w:gz") as tar:
        tar.add(src_dir / "manifest.json", arcname="manifest.json")
        tar.add(prefix_src, arcname="prefix")
        
    # Run import with a name override
    new_name = "restoredapp"
    
    # Mock _create_desktop_entry to touch the desktop file to simulate creation
    with patch.object(api, "_create_desktop_entry", side_effect=lambda name, prefix: (engine.DESKTOP_DIR / f"conjunction-{name}.desktop").touch()):
        metadata = api.import_app(archive_path, app_name=new_name)
    
    # Verify results
    assert metadata["name"] == new_name
    assert Path(metadata["prefix_path"]) == engine.PREFIX_DIR / new_name
    assert (engine.PREFIX_DIR / new_name / "game.exe").exists()
    assert (engine.APPS_DIR / f"{new_name}.json").exists()
    
    # Verify desktop entry recreated
    assert (engine.DESKTOP_DIR / f"conjunction-{new_name}.desktop").exists()

def test_import_legacy_format(tmp_path):
    api = ConjunctionAPI()
    app_name = "legacyapp"
    
    # Build a legacy (archive_version = 1) tarball
    # Uses app.manifest instead of manifest.json, and wineprefix instead of prefix
    archive_path = tmp_path / "legacyapp.tar.gz"
    src_dir = tmp_path / "legacy_src"
    src_dir.mkdir()
    
    manifest = {
        "name": app_name,
        "prefix_path": "/old/path/prefixes/legacyapp",
        "primary_exe": "/old/path/prefixes/legacyapp/run.exe",
        "archive_version": 1
    }
    with open(src_dir / "app.manifest", "w", encoding="utf-8") as f:
        json.dump(manifest, f)
        
    wineprefix_src = src_dir / "wineprefix"
    wineprefix_src.mkdir()
    (wineprefix_src / "run.exe").touch()
    
    with tarfile.open(archive_path, "w:gz") as tar:
        tar.add(src_dir / "app.manifest", arcname="app.manifest")
        tar.add(wineprefix_src, arcname="wineprefix")
        
    # Run import
    with patch.object(api, "_create_desktop_entry"):
        metadata = api.import_app(archive_path)
    
    # Verify migration works
    assert metadata["name"] == app_name
    assert Path(metadata["prefix_path"]) == engine.PREFIX_DIR / app_name
    assert (engine.PREFIX_DIR / app_name / "run.exe").exists()
    assert metadata["archive_version"] == 2
