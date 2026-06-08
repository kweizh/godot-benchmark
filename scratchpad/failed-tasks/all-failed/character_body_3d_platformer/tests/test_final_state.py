import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest


PROJECT_DIR = "/home/user/platformer3d"
ZEALT_TESTS_DIR = os.path.join(PROJECT_DIR, "_zealt_tests")
HARNESS_SRC_DIR = "/tests"
HARNESS_FILES = [
    "test_harness_jump.gd",
    "test_harness_jump.tscn",
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

def test_required_files_exist():
    required = [
        "project.godot",
        "scripts/Player.gd",
        "scenes/Player.tscn",
    ]
    for rel in required:
        full = os.path.join(PROJECT_DIR, rel)
        assert os.path.isfile(full), f"Missing required file: {full}"


def test_player_script_declares_exports_with_defaults():
    src = _read_text(os.path.join(PROJECT_DIR, "scripts/Player.gd"))
    # All defaults are float/int literals. Allow either `5.0`, `5`, or with
    # leading minus for completeness, but pin to exact required values.
    patterns = [
        (r"@export\s+var\s+speed\s*:\s*float\s*=\s*5(?:\.0+)?\b",
         "speed: float = 5.0"),
        (r"@export\s+var\s+jump_velocity\s*:\s*float\s*=\s*7\.5(?:0+)?\b",
         "jump_velocity: float = 7.5"),
        (r"@export\s+var\s+gravity\s*:\s*float\s*=\s*25(?:\.0+)?\b",
         "gravity: float = 25.0"),
        (r"@export\s+var\s+max_air_jumps\s*:\s*int\s*=\s*1\b",
         "max_air_jumps: int = 1"),
        (r"@export\s+var\s+coyote_time\s*:\s*float\s*=\s*0\.15(?:0+)?\b",
         "coyote_time: float = 0.15"),
        (r"@export\s+var\s+jump_buffer_time\s*:\s*float\s*=\s*0\.15(?:0+)?\b",
         "jump_buffer_time: float = 0.15"),
    ]
    for pattern, desc in patterns:
        assert re.search(pattern, src), (
            f"scripts/Player.gd must declare @export `{desc}`. Pattern not found."
        )


def test_player_script_declares_jumped_signal():
    src = _read_text(os.path.join(PROJECT_DIR, "scripts/Player.gd"))
    assert re.search(
        r"signal\s+jumped\s*\(\s*remaining_air_jumps\s*:\s*int\s*\)", src
    ), "scripts/Player.gd must declare `signal jumped(remaining_air_jumps: int)`."


def test_player_script_defines_required_methods():
    src = _read_text(os.path.join(PROJECT_DIR, "scripts/Player.gd"))
    assert re.search(r"func\s+_physics_process\s*\(", src), (
        "scripts/Player.gd must define `_physics_process`."
    )
    assert re.search(
        r"func\s+get_movement_state\s*\(\s*\)\s*->\s*StringName\b", src
    ), "scripts/Player.gd must define `get_movement_state() -> StringName`."


def test_player_scene_root_is_character_body_3d():
    content = _read_text(os.path.join(PROJECT_DIR, "scenes/Player.tscn"))
    # The root node line must have name="Player" and type="CharacterBody3D".
    root_pattern = re.compile(
        r'\[node\s+name="Player"\s+type="CharacterBody3D"\b', re.MULTILINE
    )
    assert root_pattern.search(content), (
        "scenes/Player.tscn root must be `[node name=\"Player\" type=\"CharacterBody3D\"]`."
    )
    assert "scripts/Player.gd" in content, (
        "scenes/Player.tscn must reference scripts/Player.gd as its script."
    )


def test_player_scene_has_capsule_collider_with_dimensions():
    content = _read_text(os.path.join(PROJECT_DIR, "scenes/Player.tscn"))
    assert re.search(
        r'\[sub_resource\s+type="CapsuleShape3D"', content
    ), "scenes/Player.tscn must declare a CapsuleShape3D sub_resource."
    # Find the CapsuleShape3D block and confirm radius/height.
    blocks = re.findall(
        r'\[sub_resource\s+type="CapsuleShape3D"[^\[]*',
        content,
    )
    matched = False
    for block in blocks:
        radius_ok = re.search(r"\bradius\s*=\s*0\.5(?:0+)?\b", block) is not None
        height_ok = re.search(r"\bheight\s*=\s*1\.8(?:0+)?\b", block) is not None
        if radius_ok and height_ok:
            matched = True
            break
    assert matched, (
        "scenes/Player.tscn must declare a CapsuleShape3D with `radius = 0.5` "
        "and `height = 1.8`."
    )
    assert re.search(
        r'\[node\s+[^\]]*type="CollisionShape3D"', content
    ), "scenes/Player.tscn must include a CollisionShape3D child node."


def test_player_scene_has_pivot_with_mesh():
    content = _read_text(os.path.join(PROJECT_DIR, "scenes/Player.tscn"))
    assert re.search(
        r'\[node\s+name="Pivot"\s+type="Node3D"', content
    ), 'scenes/Player.tscn must contain a child `[node name="Pivot" type="Node3D"]`.'
    assert re.search(
        r'\[node\s+[^\]]*type="MeshInstance3D"', content
    ), "scenes/Player.tscn must contain a MeshInstance3D node."
    primitive_meshes = [
        "BoxMesh",
        "CapsuleMesh",
        "SphereMesh",
        "CylinderMesh",
        "PrismMesh",
        "PlaneMesh",
        "QuadMesh",
        "TorusMesh",
    ]
    has_primitive = any(
        re.search(rf'\[sub_resource\s+type="{mesh}"', content) is not None
        for mesh in primitive_meshes
    )
    assert has_primitive, (
        "scenes/Player.tscn must use a built-in primitive mesh sub_resource "
        f"(one of: {', '.join(primitive_meshes)})."
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
# Runtime jump behavior harness
# ---------------------------------------------------------------------------

def test_jump_runtime_harness():
    _reset_user_data()
    result = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "res://_zealt_tests/test_harness_jump.tscn",
        ],
        capture_output=True,
        text=True,
        timeout=300,
        env=_godot_env(),
    )
    combined = (result.stdout or "") + (result.stderr or "")
    assert result.returncode == 0, (
        f"Jump runtime harness exited with code {result.returncode}:\n{combined}"
    )
    assert "HARNESS_OK" in result.stdout, (
        f"Jump runtime harness did not print HARNESS_OK. Output:\n{combined}"
    )
