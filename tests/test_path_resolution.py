import pytest
from unittest.mock import patch, MagicMock
from pathlib import Path
import os
import sys
from engine import get_user_home

# Helper class to simulate pwd module if it doesn't exist on the host platform (Windows)
class MockPwEntry:
    def __init__(self, pw_dir):
        self.pw_dir = pw_dir

def get_absolute_dummy_path(suffix):
    if os.name == "nt":
        return Path("C:/") / suffix
    return Path("/") / suffix

def test_get_user_home_normal_user():
    dummy_home = get_absolute_dummy_path("home/normal")
    
    # Remove SUDO_USER, set HOME to dummy_home
    with patch.dict(os.environ, {"HOME": str(dummy_home)}, clear=True), \
         patch("os.path.expanduser", return_value=""), \
         patch("pathlib.Path.home", return_value=dummy_home):
        home = get_user_home()
        assert home == dummy_home

def test_get_user_home_sudo_user():
    dummy_sudo_home = get_absolute_dummy_path("home/sudouser")
    mock_pwd = MagicMock()
    mock_pwd.getpwnam.return_value = MockPwEntry(str(dummy_sudo_home))
    
    with patch.dict(os.environ, {"SUDO_USER": "sudouser", "HOME": "/root"}, clear=True), \
         patch.dict(sys.modules, {"pwd": mock_pwd}), \
         patch("os.path.expanduser", return_value=""):
        home = get_user_home()
        assert home == dummy_sudo_home

def test_get_user_home_missing_env_fallback():
    dummy_pwd_home = get_absolute_dummy_path("home/pwduser")
    mock_pwd = MagicMock()
    mock_pwd.getpwuid.return_value = MockPwEntry(str(dummy_pwd_home))
    
    with patch.dict(os.environ, {}, clear=True), \
         patch.dict(sys.modules, {"pwd": mock_pwd}), \
         patch("os.path.expanduser", return_value=""), \
         patch("pathlib.Path.home", return_value=dummy_pwd_home):
        home = get_user_home()
        assert home == dummy_pwd_home

def test_get_user_home_invalid_path_raises(tmp_path):
    # What if HOME env points to a file?
    file_path = tmp_path / "home_file"
    file_path.touch()
    
    with patch.dict(os.environ, {"HOME": str(file_path)}, clear=True), \
         patch("os.path.expanduser", return_value=""), \
         patch("pathlib.Path.home", return_value=file_path):
        with pytest.raises(RuntimeError) as excinfo:
            get_user_home()
        assert "not a directory" in str(excinfo.value)

def test_get_user_home_empty_or_root_raises():
    # What if resolved home is root '/' or empty?
    for invalid_path in ["", "/", "."]:
        with patch.dict(os.environ, {"HOME": invalid_path}, clear=True), \
             patch("os.path.expanduser", return_value=""), \
             patch("pathlib.Path.home", return_value=Path(invalid_path)):
            with pytest.raises(RuntimeError):
                get_user_home()
