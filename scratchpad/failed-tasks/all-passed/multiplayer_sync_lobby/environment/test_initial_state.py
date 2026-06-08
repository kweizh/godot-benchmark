import os
import shutil
import pytest

PROJECT_DIR = "/home/user/godot-benchmark"

def test_godot_binary_available():
    """Verify that Godot 4 binary is installed and available in PATH."""
    assert shutil.which("godot") is not None, "Godot binary not found in PATH."

def test_project_dir_exists():
    """Verify that the project directory exists."""
    assert os.path.isdir(PROJECT_DIR), f"Project directory {PROJECT_DIR} does not exist."

def test_xprocess_installed():
    """Verify that pytest-xprocess is installed and importable."""
    try:
        import xprocess
    except ImportError:
        pytest.fail("pytest-xprocess is not installed in the python environment.")
