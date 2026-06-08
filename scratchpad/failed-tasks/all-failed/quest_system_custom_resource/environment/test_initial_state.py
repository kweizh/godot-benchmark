import os
import shutil
import subprocess

PROJECT_DIR = "/home/user/quest_project"


def test_godot_binary_available():
    assert shutil.which("godot") is not None, "godot binary not found in PATH."


def test_godot_runs_headless():
    result = subprocess.run(
        ["godot", "--headless", "--version"],
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert result.returncode == 0, (
        f"`godot --headless --version` failed with code {result.returncode}: "
        f"stdout={result.stdout!r} stderr={result.stderr!r}"
    )
    combined = (result.stdout + result.stderr).strip()
    assert combined.startswith("4."), (
        f"Expected Godot 4.x, got version output: {combined!r}"
    )


def test_project_directory_exists():
    assert os.path.isdir(PROJECT_DIR), (
        f"Expected project directory {PROJECT_DIR} to exist before the task starts."
    )


def test_project_godot_exists():
    project_godot = os.path.join(PROJECT_DIR, "project.godot")
    assert os.path.isfile(project_godot), (
        f"Expected Godot project file {project_godot} to exist before the task starts."
    )
