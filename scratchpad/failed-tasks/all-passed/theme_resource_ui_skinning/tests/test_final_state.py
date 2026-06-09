import os
import re
import shutil
import subprocess

import pytest


PROJECT_DIR = "/home/user/theme_lab"
ZEALT_TESTS_DIR = os.path.join(PROJECT_DIR, "_zealt_tests")
HARNESS_SRC_DIR = "/tests"
HARNESS_FILES = [
    "test_harness_theme.gd",
    "test_harness_theme.tscn",
]

XDG_DATA_HOME = "/tmp/godot_test_xdg"


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


def test_required_files_exist():
    required = [
        "project.godot",
        "scenes/main.tscn",
        "scripts/main.gd",
    ]
    for rel in required:
        full = os.path.join(PROJECT_DIR, rel)
        assert os.path.isfile(full), f"Missing required file: {full}"


def test_main_scene_registered_in_project_godot():
    content = _read_text(os.path.join(PROJECT_DIR, "project.godot"))
    pattern = re.compile(
        r'^run/main_scene\s*=\s*"res://scenes/main\.tscn"\s*$',
        re.MULTILINE,
    )
    assert pattern.search(content), (
        "project.godot must set `run/main_scene=\"res://scenes/main.tscn\"` "
        "in the [application] section."
    )


def test_main_scene_node_tree():
    tscn = _read_text(os.path.join(PROJECT_DIR, "scenes/main.tscn"))
    # Root Control must reference scripts/main.gd.
    assert re.search(r'\[node\s+name="Root"\s+type="Control"', tscn), (
        "scenes/main.tscn must declare a root node named 'Root' of type 'Control'."
    )
    assert "scripts/main.gd" in tscn, (
        "scenes/main.tscn must attach scripts/main.gd to the Root node "
        "(expected an ext_resource pointing at res://scripts/main.gd)."
    )
    # Child nodes with their exact types.
    expected_nodes = [
        ("MainPanel", "Panel", '"."'),
        ("TitleLabel", "Label", '"MainPanel"'),
        ("DefaultButton", "Button", '"MainPanel"'),
        ("PrimaryButton", "Button", '"MainPanel"'),
        ("DangerButton", "Button", '"MainPanel"'),
    ]
    for name, ntype, parent in expected_nodes:
        pat = re.compile(
            r'\[node\s+name="' + re.escape(name) + r'"\s+type="' + re.escape(ntype) + r'"\s+parent=' + parent,
            re.MULTILINE,
        )
        assert pat.search(tscn), (
            f"scenes/main.tscn must contain a node name=\"{name}\" type=\"{ntype}\" "
            f"parent={parent}."
        )


def test_main_script_has_public_api():
    gd = _read_text(os.path.join(PROJECT_DIR, "scripts/main.gd"))
    assert re.search(r"\bfunc\s+apply_theme\s*\(", gd), (
        "scripts/main.gd must define `func apply_theme(...)`."
    )
    assert re.search(r"\bfunc\s+get_current_mode\s*\(", gd), (
        "scripts/main.gd must define `func get_current_mode(...)`."
    )
    assert "Theme.new(" in gd or "Theme.new (" in gd, (
        "scripts/main.gd must construct the Theme at runtime via `Theme.new()`."
    )
    assert "StyleBoxFlat.new(" in gd or "StyleBoxFlat.new (" in gd, (
        "scripts/main.gd must construct styleboxes at runtime via `StyleBoxFlat.new()`."
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
# Runtime theme behavior verified through the harness scene.
# ---------------------------------------------------------------------------

def test_theme_runtime_harness():
    _reset_user_data()
    result = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "res://_zealt_tests/test_harness_theme.tscn",
        ],
        capture_output=True,
        text=True,
        timeout=240,
        env=_godot_env(),
    )
    combined = (result.stdout or "") + (result.stderr or "")
    assert result.returncode == 0, (
        f"Theme harness exited with code {result.returncode}:\n{combined}"
    )
    assert "HARNESS_OK" in result.stdout, (
        f"Theme harness did not print HARNESS_OK. Output:\n{combined}"
    )
