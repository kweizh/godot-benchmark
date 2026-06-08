import os
import shutil
import subprocess


PROJECT_DIR = "/home/user/project"


def test_godot_binary_available():
    assert shutil.which("godot") is not None, "godot binary not found in PATH."


def test_python3_available():
    assert shutil.which("python3") is not None, (
        "python3 binary not found in PATH; required to launch the local HTTP test server."
    )


def test_godot_is_version_4():
    proc = subprocess.run(
        ["godot", "--version"],
        capture_output=True,
        text=True,
        check=False,
    )
    out = (proc.stdout or "") + (proc.stderr or "")
    assert proc.returncode == 0, f"`godot --version` failed: {out}"
    assert out.strip().startswith("4."), (
        f"Expected Godot 4.x to be installed, got: {out.strip()}"
    )


def test_godot_headless_runs():
    proc = subprocess.run(
        ["godot", "--headless", "--quit"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0, (
        f"`godot --headless --quit` failed with exit {proc.returncode}: "
        f"{proc.stdout}\n{proc.stderr}"
    )


def test_project_dir_exists():
    assert os.path.isdir(PROJECT_DIR), f"Project directory {PROJECT_DIR} does not exist."


def test_project_godot_exists():
    project_file = os.path.join(PROJECT_DIR, "project.godot")
    assert os.path.isfile(project_file), (
        f"project.godot not found at {project_file}; "
        "Godot project must be initialized before evaluation."
    )
