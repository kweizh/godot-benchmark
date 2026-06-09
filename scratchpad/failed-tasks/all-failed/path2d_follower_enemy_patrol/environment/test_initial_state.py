import json
import os
import shutil
import subprocess

import pytest

PROJECT_DIR = "/home/user/myproject"
PROJECT_GODOT = os.path.join(PROJECT_DIR, "project.godot")
DATA_DIR = os.path.join(PROJECT_DIR, "data")
SCENES_DIR = os.path.join(PROJECT_DIR, "scenes")
SCRIPTS_DIR = os.path.join(PROJECT_DIR, "scripts")
WAYPOINTS_JSON = os.path.join(DATA_DIR, "waypoints.json")


def test_godot_binary_available():
    assert shutil.which("godot") is not None, "godot binary not found in PATH."


def test_godot_runs_headless():
    result = subprocess.run(
        ["godot", "--headless", "--version"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert result.returncode == 0, (
        f"`godot --headless --version` failed with code {result.returncode}: "
        f"stdout={result.stdout!r}, stderr={result.stderr!r}"
    )
    assert result.stdout.strip().startswith("4."), (
        f"Expected Godot 4.x, got version output: {result.stdout!r}"
    )


def test_project_dir_exists():
    assert os.path.isdir(PROJECT_DIR), f"Project directory {PROJECT_DIR} does not exist."


def test_project_godot_exists():
    assert os.path.isfile(PROJECT_GODOT), (
        f"project.godot manifest {PROJECT_GODOT} does not exist."
    )


def test_scaffold_dirs_exist():
    for d in (DATA_DIR, SCENES_DIR, SCRIPTS_DIR):
        assert os.path.isdir(d), f"Scaffold directory {d} does not exist."


def test_waypoints_json_exists():
    assert os.path.isfile(WAYPOINTS_JSON), (
        f"Initial waypoints file {WAYPOINTS_JSON} does not exist."
    )


def test_waypoints_json_schema():
    with open(WAYPOINTS_JSON, "r") as f:
        data = json.load(f)
    assert isinstance(data, dict), "waypoints.json must contain a JSON object."
    assert "waypoints" in data, "waypoints.json must contain a 'waypoints' key."
    waypoints = data["waypoints"]
    assert isinstance(waypoints, list), "'waypoints' must be a JSON array."
    assert len(waypoints) >= 2, "'waypoints' must contain at least two entries."
    for i, point in enumerate(waypoints):
        assert isinstance(point, list) and len(point) == 2, (
            f"waypoints[{i}] must be a [x, y] pair."
        )
        assert all(isinstance(c, (int, float)) for c in point), (
            f"waypoints[{i}] coordinates must be numeric."
        )
