import os
import re
import shutil
import subprocess

import pytest


PROJECT_DIR = "/home/user/state_machine_player"
ZEALT_TESTS_DIR = os.path.join(PROJECT_DIR, "_zealt_tests")
HARNESS_SRC_DIR = "/tests"
HARNESS_FILES = [
    "test_harness_action.gd",
    "test_harness_action.tscn",
    "test_harness_states.gd",
    "test_harness_states.tscn",
    "test_harness_attack.gd",
    "test_harness_attack.tscn",
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
# Static file/structure checks
# ---------------------------------------------------------------------------

REQUIRED_FILES = [
    "project.godot",
    "scripts/states/State.gd",
    "scripts/states/IdleState.gd",
    "scripts/states/RunState.gd",
    "scripts/states/JumpState.gd",
    "scripts/states/FallState.gd",
    "scripts/states/AttackState.gd",
    "scripts/StateMachine.gd",
    "scripts/Player.gd",
    "scenes/Player.tscn",
]


def test_required_files_exist():
    for rel in REQUIRED_FILES:
        full = os.path.join(PROJECT_DIR, rel)
        assert os.path.isfile(full), f"Missing required file: {full}"


def test_state_base_class():
    content = _read_text(os.path.join(PROJECT_DIR, "scripts/states/State.gd"))
    assert re.search(r"\bclass_name\s+State\b", content), (
        "scripts/states/State.gd must declare `class_name State`."
    )
    assert re.search(r"\bextends\s+Node\b", content), (
        "scripts/states/State.gd must `extends Node`."
    )


def test_state_machine_class_and_signal():
    content = _read_text(os.path.join(PROJECT_DIR, "scripts/StateMachine.gd"))
    assert re.search(r"\bclass_name\s+StateMachine\b", content), (
        "scripts/StateMachine.gd must declare `class_name StateMachine`."
    )
    assert re.search(r"\bextends\s+Node\b", content), (
        "scripts/StateMachine.gd must `extends Node`."
    )
    assert re.search(r"\bsignal\s+state_changed\b", content), (
        "scripts/StateMachine.gd must declare `signal state_changed`."
    )


@pytest.mark.parametrize(
    "filename,classname",
    [
        ("IdleState.gd", "IdleState"),
        ("RunState.gd", "RunState"),
        ("JumpState.gd", "JumpState"),
        ("FallState.gd", "FallState"),
        ("AttackState.gd", "AttackState"),
    ],
)
def test_concrete_state_classes(filename, classname):
    path = os.path.join(PROJECT_DIR, "scripts/states", filename)
    content = _read_text(path)
    assert re.search(rf"\bclass_name\s+{classname}\b", content), (
        f"{filename} must declare `class_name {classname}`."
    )
    assert re.search(r"\bextends\s+State\b", content), (
        f"{filename} must `extends State`."
    )


def test_attack_action_registered_with_J_key():
    content = _read_text(os.path.join(PROJECT_DIR, "project.godot"))
    # The action must appear under (or after) the [input] section header.
    input_section_match = re.search(r"^\[input\]\s*$", content, re.MULTILINE)
    assert input_section_match, "project.godot must contain an [input] section."
    after_input = content[input_section_match.end():]
    # Stop at the next section header so we only inspect [input] content.
    next_section = re.search(r"^\[[^\]]+\]\s*$", after_input, re.MULTILINE)
    input_block = after_input if next_section is None else after_input[: next_section.start()]
    assert re.search(r"^attack\s*=", input_block, re.MULTILINE), (
        "project.godot [input] section must define an `attack` action."
    )
    # The attack entry should reference an InputEventKey with physical_keycode or
    # keycode 74 (the `J` key).
    attack_line_match = re.search(r"^attack\s*=.+$", input_block, re.MULTILINE | re.DOTALL)
    assert attack_line_match, "Could not parse the `attack` action definition."
    attack_block = attack_line_match.group(0)
    assert "InputEventKey" in attack_block, (
        "The `attack` action must include an InputEventKey event."
    )
    assert re.search(r"(physical_keycode|keycode)\s*:\s*74", attack_block), (
        "The `attack` action must bind a key event with keycode 74 (the J key)."
    )


def test_player_scene_structure():
    content = _read_text(os.path.join(PROJECT_DIR, "scenes/Player.tscn"))
    assert 'type="CharacterBody2D"' in content, (
        "scenes/Player.tscn root must be a CharacterBody2D."
    )
    # Must reference Player.gd.
    assert "Player.gd" in content, "scenes/Player.tscn must reference Player.gd."
    # Must contain a StateMachine child node and state children.
    assert re.search(r'\bname="StateMachine"', content), (
        "scenes/Player.tscn must contain a child node named StateMachine."
    )
    for state_name in ["Idle", "Run", "Jump", "Fall", "Attack"]:
        assert re.search(rf'\bname="{state_name}"', content), (
            f"scenes/Player.tscn must contain a child node named {state_name}."
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
    for marker in ["SCRIPT ERROR", "Parse Error", "Failed to load"]:
        assert marker not in combined, (
            f"Godot reported '{marker}' while loading the project:\n{combined}"
        )


# ---------------------------------------------------------------------------
# Runtime harnesses
# ---------------------------------------------------------------------------

def test_attack_action_harness():
    _reset_user_data()
    result = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "res://_zealt_tests/test_harness_action.tscn",
        ],
        capture_output=True,
        text=True,
        timeout=120,
        env=_godot_env(),
    )
    combined = (result.stdout or "") + (result.stderr or "")
    assert result.returncode == 0, (
        f"action harness exited with code {result.returncode}:\n{combined}"
    )
    assert "ACTION_OK" in result.stdout, (
        f"action harness did not print ACTION_OK. Output:\n{combined}"
    )


def test_state_transitions_harness():
    _reset_user_data()
    result = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "res://_zealt_tests/test_harness_states.tscn",
        ],
        capture_output=True,
        text=True,
        timeout=180,
        env=_godot_env(),
    )
    combined = (result.stdout or "") + (result.stderr or "")
    assert result.returncode == 0, (
        f"states harness exited with code {result.returncode}:\n{combined}"
    )
    assert "STATES_OK" in result.stdout, (
        f"states harness did not print STATES_OK. Output:\n{combined}"
    )


def test_attack_timing_harness():
    _reset_user_data()
    result = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "res://_zealt_tests/test_harness_attack.tscn",
        ],
        capture_output=True,
        text=True,
        timeout=120,
        env=_godot_env(),
    )
    combined = (result.stdout or "") + (result.stderr or "")
    assert result.returncode == 0, (
        f"attack harness exited with code {result.returncode}:\n{combined}"
    )
    assert "ATTACK_OK" in result.stdout, (
        f"attack harness did not print ATTACK_OK. Output:\n{combined}"
    )
