import os
import shutil
import subprocess

PROJECT_DIR = "/home/user/myproject"


def test_godot_binary_available():
    assert shutil.which("godot") is not None, "godot binary not found in PATH."


def test_godot_version_is_4():
    result = subprocess.run(
        ["godot", "--version"], capture_output=True, text=True, timeout=30
    )
    assert result.returncode == 0, f"`godot --version` failed: {result.stderr}"
    version_output = (result.stdout + result.stderr).strip()
    assert version_output.startswith("4."), (
        f"Expected Godot 4.x but got: {version_output!r}"
    )


def test_project_dir_exists():
    assert os.path.isdir(PROJECT_DIR), f"Project dir {PROJECT_DIR} does not exist."


def test_project_godot_exists():
    project_file = os.path.join(PROJECT_DIR, "project.godot")
    assert os.path.isfile(project_file), (
        f"Godot project file {project_file} does not exist."
    )


def test_scenes_dir_exists():
    scenes_dir = os.path.join(PROJECT_DIR, "scenes")
    assert os.path.isdir(scenes_dir), (
        f"Expected scenes directory {scenes_dir} to exist."
    )


def test_scripts_dir_exists():
    scripts_dir = os.path.join(PROJECT_DIR, "scripts")
    assert os.path.isdir(scripts_dir), (
        f"Expected scripts directory {scripts_dir} to exist."
    )
