import os
import re
import shutil
import subprocess

import pytest


PROJECT_DIR = "/home/user/water_shader"
ZEALT_TESTS_DIR = os.path.join(PROJECT_DIR, "_zealt_tests")
HARNESS_SRC_DIR = "/tests"
HARNESS_FILES = [
    "test_harness_runtime.gd",
    "test_harness_runtime.tscn",
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
        "shaders/water_distortion.gdshader",
        "scenes/Water.tscn",
    ]
    for rel in required:
        full = os.path.join(PROJECT_DIR, rel)
        assert os.path.isfile(full), f"Missing required file: {full}"


def _first_meaningful_line(content: str) -> str:
    for raw in content.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("//"):
            continue
        # Skip block-comment style header lines, very simple heuristic.
        if line.startswith("/*") or line.startswith("*"):
            continue
        return line
    return ""


def test_shader_starts_with_canvas_item_type():
    content = _read_text(os.path.join(PROJECT_DIR, "shaders/water_distortion.gdshader"))
    first = _first_meaningful_line(content)
    assert first == "shader_type canvas_item;", (
        "First non-comment, non-blank line of water_distortion.gdshader must be "
        f"`shader_type canvas_item;` (got {first!r})."
    )


def test_shader_declares_required_uniforms():
    content = _read_text(os.path.join(PROJECT_DIR, "shaders/water_distortion.gdshader"))

    # time_scale, wave_amplitude, wave_frequency: float uniforms.
    for name in ("time_scale", "wave_amplitude", "wave_frequency"):
        pat = re.compile(r"uniform\s+float\s+" + re.escape(name) + r"\b")
        assert pat.search(content), (
            f"Shader is missing required uniform `float {name}` declaration."
        )

    # tint_color: vec4 uniform with source_color hint.
    tint_pat = re.compile(
        r"uniform\s+vec4\s+tint_color\b[^;]*source_color", re.DOTALL
    )
    assert tint_pat.search(content), (
        "Shader is missing `uniform vec4 tint_color` declaration with `source_color` hint."
    )

    # screen_texture: sampler2D uniform with hint_screen_texture.
    screen_pat = re.compile(
        r"uniform\s+sampler2D\s+screen_texture\b[^;]*hint_screen_texture", re.DOTALL
    )
    assert screen_pat.search(content), (
        "Shader is missing `uniform sampler2D screen_texture` with `hint_screen_texture` hint."
    )


def test_shader_fragment_function_uses_required_builtins():
    content = _read_text(os.path.join(PROJECT_DIR, "shaders/water_distortion.gdshader"))

    assert re.search(r"\bvoid\s+fragment\s*\(\s*\)", content), (
        "Shader must define a `fragment()` function."
    )
    assert "SCREEN_UV" in content, "fragment() must reference SCREEN_UV."
    assert re.search(r"\bTIME\b", content), "fragment() must reference TIME."
    assert ("sin(" in content) or ("cos(" in content), (
        "fragment() must use at least one of sin(...) or cos(...)."
    )
    assert "mix(" in content, "fragment() must use mix(...) for the tint blend."


def test_water_scene_root_is_color_rect_with_shader_material():
    content = _read_text(os.path.join(PROJECT_DIR, "scenes/Water.tscn"))
    assert re.search(r'type="ColorRect"', content), (
        "scenes/Water.tscn must declare a root node of type ColorRect."
    )
    assert "ShaderMaterial" in content, (
        "scenes/Water.tscn must contain a ShaderMaterial."
    )
    assert "water_distortion.gdshader" in content, (
        "scenes/Water.tscn must reference shaders/water_distortion.gdshader."
    )


# ---------------------------------------------------------------------------
# Godot loads the project cleanly
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
    forbidden = ["SCRIPT ERROR", "Parse Error", "Failed to load", "Cannot compile"]
    for marker in forbidden:
        assert marker not in combined, (
            f"Godot reported '{marker}' while loading the project:\n{combined}"
        )


# ---------------------------------------------------------------------------
# Runtime behavior (shader compile + uniform propagation)
# ---------------------------------------------------------------------------

def test_runtime_harness():
    _reset_user_data()
    result = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "res://_zealt_tests/test_harness_runtime.tscn",
        ],
        capture_output=True,
        text=True,
        timeout=180,
        env=_godot_env(),
    )
    combined = (result.stdout or "") + (result.stderr or "")
    assert result.returncode == 0, (
        f"Runtime harness exited with code {result.returncode}:\n{combined}"
    )
    assert "HARNESS_OK" in result.stdout, (
        f"Runtime harness did not print HARNESS_OK. Output:\n{combined}"
    )
    # Defensive: ensure no shader compile errors leaked into the output.
    for marker in ("Cannot compile", "SHADER ERROR", "Parse Error"):
        assert marker not in combined, (
            f"Runtime harness output contained forbidden marker '{marker}':\n{combined}"
        )
