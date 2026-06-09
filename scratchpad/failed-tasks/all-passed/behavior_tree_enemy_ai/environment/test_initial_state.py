import os
import shutil
import subprocess

PROJECT_DIR = "/home/user/myproject"


def test_godot_binary_available():
    assert shutil.which("godot") is not None, (
        "godot binary not found in PATH; the Dockerfile must install Godot 4 headless."
    )


def test_godot_is_version_4():
    result = subprocess.run(
        ["godot", "--headless", "--version"],
        capture_output=True,
        text=True,
        timeout=60,
    )
    combined = (result.stdout or "") + (result.stderr or "")
    assert result.returncode == 0, (
        f"`godot --headless --version` exited with code {result.returncode}: {combined}"
    )
    assert combined.strip().startswith("4."), (
        f"Expected Godot 4.x, got version output: {combined!r}"
    )


def test_project_dir_exists():
    assert os.path.isdir(PROJECT_DIR), (
        f"Project directory {PROJECT_DIR} must exist as a Godot project root."
    )


def test_project_godot_file_exists():
    project_file = os.path.join(PROJECT_DIR, "project.godot")
    assert os.path.isfile(project_file), (
        f"Expected a Godot project manifest at {project_file}."
    )


def test_project_godot_declares_config_version_5():
    project_file = os.path.join(PROJECT_DIR, "project.godot")
    with open(project_file, "r", encoding="utf-8") as fh:
        content = fh.read()
    assert "config_version=5" in content, (
        f"Expected `config_version=5` (Godot 4 project format) inside {project_file}."
    )
