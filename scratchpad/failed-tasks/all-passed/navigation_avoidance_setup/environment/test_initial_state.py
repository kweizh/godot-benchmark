import shutil
import subprocess

def test_godot_binary_available():
    """Verify that the Godot 4 executable is installed and available in PATH."""
    godot_path = shutil.which("godot")
    assert godot_path is not None, "Godot 4 binary ('godot') not found in PATH."

def test_godot_version():
    """Verify that Godot 4 is installed and is version 4.x."""
    try:
        result = subprocess.run(
            ["godot", "--version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
        version = result.stdout.strip()
        assert version.startswith("4."), f"Expected Godot version 4.x, but got: {version}"
    except Exception as e:
        assert False, f"Failed to execute 'godot --version': {e}"
