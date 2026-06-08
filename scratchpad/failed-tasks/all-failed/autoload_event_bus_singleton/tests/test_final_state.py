import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest


PROJECT_DIR = "/home/user/myproject"
ZEALT_TESTS_DIR = os.path.join(PROJECT_DIR, "_zealt_tests")
HARNESS_SRC_DIR = "/tests"
HARNESS_FILES = [
    "test_harness_bus.gd",
    "test_harness_bus.tscn",
    "freed_target.gd",
]

XDG_DATA_HOME = "/tmp/godot_test_xdg"

REQUIRED_RESULT_KEYS = [
    "autoload",
    "multi_subs",
    "unsubscribe",
    "publish_once",
    "middleware_drop",
    "middleware_transform",
    "freed_autoprune",
    "clear_channel",
]


def _godot_env() -> dict:
    env = os.environ.copy()
    env["XDG_DATA_HOME"] = XDG_DATA_HOME
    env.pop("DISPLAY", None)
    return env


def _reset_user_data() -> None:
    if os.path.isdir(XDG_DATA_HOME):
        shutil.rmtree(XDG_DATA_HOME, ignore_errors=True)
    os.makedirs(XDG_DATA_HOME, exist_ok=True)


def _install_harnesses() -> None:
    os.makedirs(ZEALT_TESTS_DIR, exist_ok=True)
    for fname in HARNESS_FILES:
        src = os.path.join(HARNESS_SRC_DIR, fname)
        dst = os.path.join(ZEALT_TESTS_DIR, fname)
        assert os.path.isfile(src), f"Harness source missing: {src}"
        shutil.copyfile(src, dst)


def _read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


@pytest.fixture(scope="module", autouse=True)
def _setup_module():
    _install_harnesses()
    yield
    shutil.rmtree(ZEALT_TESTS_DIR, ignore_errors=True)


# ---------------------------------------------------------------------------
# Static structure checks
# ---------------------------------------------------------------------------

def test_project_godot_exists():
    p = os.path.join(PROJECT_DIR, "project.godot")
    assert os.path.isfile(p), f"Missing Godot project file at {p}"


def test_bus_script_exists():
    p = os.path.join(PROJECT_DIR, "autoloads", "Bus.gd")
    assert os.path.isfile(p), (
        f"Expected the autoload script at {p} (autoloads/Bus.gd)."
    )


def test_bus_declares_class_name():
    p = os.path.join(PROJECT_DIR, "autoloads", "Bus.gd")
    content = _read_text(p)
    assert re.search(r"^class_name\s+Bus\b", content, re.MULTILINE), (
        "autoloads/Bus.gd must declare `class_name Bus`."
    )


def test_autoload_registered_in_project_godot():
    content = _read_text(os.path.join(PROJECT_DIR, "project.godot"))
    # Accept either the standard `*` autoload marker or no marker.
    pattern = re.compile(
        r'^Bus\s*=\s*"\*?res://autoloads/Bus\.gd"\s*$',
        re.MULTILINE,
    )
    assert pattern.search(content), (
        "project.godot must register `Bus=\"*res://autoloads/Bus.gd\"` "
        "in the [autoload] section."
    )


# ---------------------------------------------------------------------------
# Godot loads project cleanly
# ---------------------------------------------------------------------------

def test_project_loads_without_errors():
    _reset_user_data()
    result = subprocess.run(
        ["godot", "--headless", "--path", PROJECT_DIR, "--quit"],
        capture_output=True,
        text=True,
        timeout=120,
        env=_godot_env(),
    )
    combined = (result.stdout or "") + (result.stderr or "")
    assert result.returncode == 0, (
        f"`godot --quit` exited with code {result.returncode}:\n"
        f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
    )
    forbidden = ["SCRIPT ERROR", "Parse Error", "Failed to load"]
    for marker in forbidden:
        assert marker not in combined, (
            f"Godot reported '{marker}' while loading the project:\n{combined}"
        )


# ---------------------------------------------------------------------------
# Runtime behavior — full Bus contract
# ---------------------------------------------------------------------------

def _run_harness() -> dict:
    _reset_user_data()
    result = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "res://_zealt_tests/test_harness_bus.tscn",
        ],
        capture_output=True,
        text=True,
        timeout=180,
        env=_godot_env(),
    )
    combined = (result.stdout or "") + (result.stderr or "")
    assert result.returncode == 0, (
        f"Bus harness exited with code {result.returncode}:\n{combined}"
    )
    match = re.search(r"^RESULTS=(\{.*\})\s*$", result.stdout, re.MULTILINE)
    assert match, (
        f"Bus harness did not print RESULTS=<json>. Output:\n{combined}"
    )
    try:
        data = json.loads(match.group(1))
    except json.JSONDecodeError as e:
        raise AssertionError(
            f"Failed to parse RESULTS json: {e}; raw: {match.group(1)}"
        )
    return data


@pytest.fixture(scope="module")
def harness_results():
    return _run_harness()


def test_harness_autoload(harness_results):
    assert harness_results.get("autoload") is True, (
        "Bus autoload not found at /root/Bus."
    )


def test_harness_multi_subs(harness_results):
    assert harness_results.get("multi_subs") is True, (
        "Multiple subscriptions on the same channel did not all receive the payload."
    )


def test_harness_unsubscribe(harness_results):
    assert harness_results.get("unsubscribe") is True, (
        "unsubscribe() did not behave correctly (return value or removal)."
    )


def test_harness_publish_once(harness_results):
    assert harness_results.get("publish_once") is True, (
        "publish_once() must dispatch once then unsubscribe every subscriber on the channel."
    )


def test_harness_middleware_drop(harness_results):
    assert harness_results.get("middleware_drop") is True, (
        "Middleware returning null must drop subscriber dispatch, "
        "but event_published signal must still fire."
    )


def test_harness_middleware_transform(harness_results):
    assert harness_results.get("middleware_transform") is True, (
        "Middleware returning a transformed payload must reach subscribers."
    )


def test_harness_freed_autoprune(harness_results):
    assert harness_results.get("freed_autoprune") is True, (
        "Subscriptions whose target Object was freed must be auto-pruned on publish."
    )


def test_harness_clear_channel(harness_results):
    assert harness_results.get("clear_channel") is True, (
        "clear_channel() must remove every subscriber from a channel."
    )
