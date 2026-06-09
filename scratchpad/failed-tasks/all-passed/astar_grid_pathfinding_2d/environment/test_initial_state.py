import json
import os
import shutil
import subprocess

PROJECT_DIR = "/home/user/myproject"
LEVEL_PATH = os.path.join(PROJECT_DIR, "levels", "test_level.json")
PROJECT_GODOT_PATH = os.path.join(PROJECT_DIR, "project.godot")


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
        f"`godot --headless --version` failed with exit code {result.returncode}. "
        f"stderr: {result.stderr}"
    )
    assert result.stdout.strip().startswith("4."), (
        f"Expected Godot 4.x but got version output: {result.stdout!r}"
    )


def test_project_directory_exists():
    assert os.path.isdir(PROJECT_DIR), (
        f"Project directory {PROJECT_DIR} does not exist."
    )


def test_project_godot_file_exists():
    assert os.path.isfile(PROJECT_GODOT_PATH), (
        f"project.godot scaffold not found at {PROJECT_GODOT_PATH}; "
        f"the agent should not need to create this file."
    )


def test_level_json_exists():
    assert os.path.isfile(LEVEL_PATH), (
        f"Level layout file not found at {LEVEL_PATH}; "
        f"the agent should not need to create this file."
    )


def test_level_json_has_expected_layout():
    with open(LEVEL_PATH) as f:
        data = json.load(f)
    assert data.get("size") == [8, 8], (
        f"Expected level size [8, 8], got {data.get('size')!r}"
    )
    expected_solid = [[3, 1], [3, 2], [3, 3], [3, 4], [3, 5], [3, 6]]
    actual_solid = data.get("solid")
    assert isinstance(actual_solid, list), (
        f"Expected 'solid' to be a list, got {type(actual_solid).__name__}"
    )
    actual_set = {tuple(pair) for pair in actual_solid}
    expected_set = {tuple(pair) for pair in expected_solid}
    assert actual_set == expected_set, (
        f"Solid cells differ. Expected {expected_set!r}, got {actual_set!r}"
    )
    assert data.get("weights") == [], (
        f"Expected 'weights' to be an empty list, got {data.get('weights')!r}"
    )


def test_scripts_directory_writable():
    scripts_dir = os.path.join(PROJECT_DIR, "scripts")
    if not os.path.isdir(scripts_dir):
        # Not strictly required at this point; the executor may create it.
        return
    assert os.access(scripts_dir, os.W_OK), (
        f"scripts directory {scripts_dir} exists but is not writable."
    )
