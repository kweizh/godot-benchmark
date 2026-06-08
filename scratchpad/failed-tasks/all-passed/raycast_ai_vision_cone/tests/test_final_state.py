import json
import os
import subprocess

PROJECT_DIR = "/home/user/godot_project"
RESULTS_PATH = os.path.join(PROJECT_DIR, "test_results.json")
HARNESS = "res://tests/run_tests.gd"


def _run_harness():
    if os.path.exists(RESULTS_PATH):
        os.remove(RESULTS_PATH)
    result = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "--script",
            HARNESS,
        ],
        capture_output=True,
        text=True,
        timeout=180,
        cwd=PROJECT_DIR,
    )
    return result


def _load_results():
    assert os.path.isfile(RESULTS_PATH), (
        f"Test results file {RESULTS_PATH} was not produced by the harness."
    )
    with open(RESULTS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def test_vision_cone_script_exists():
    path = os.path.join(PROJECT_DIR, "scripts", "VisionCone.gd")
    assert os.path.isfile(path), (
        f"Expected VisionCone script at {path}, not found."
    )


def test_cone_test_scene_exists():
    path = os.path.join(PROJECT_DIR, "tests", "cone_test.tscn")
    assert os.path.isfile(path), (
        f"Expected cone test scene at {path}, not found."
    )


def test_headless_harness_executes_successfully():
    result = _run_harness()
    assert result.returncode == 0, (
        "Headless test harness exited with non-zero status.\n"
        f"stdout:\n{result.stdout}\n\nstderr:\n{result.stderr}"
    )
    results = _load_results()
    assert isinstance(results, dict), (
        f"Expected harness JSON output to be an object, got: {type(results).__name__}"
    )
    assert "assertions" in results, (
        f"Harness output missing 'assertions' key: {results!r}"
    )


def test_is_point_in_cone_inside():
    results = _load_results()
    a = results["assertions"].get("is_point_in_cone_inside")
    assert a is not None, "Missing assertion: is_point_in_cone_inside"
    assert a.get("passed") is True, (
        f"is_point_in_cone(Vector2(50, 0)) should be true for facing=(1,0), "
        f"angle=90, range=200. Got: {a}"
    )


def test_is_point_in_cone_outside_angle():
    results = _load_results()
    a = results["assertions"].get("is_point_in_cone_outside_angle")
    assert a is not None, "Missing assertion: is_point_in_cone_outside_angle"
    assert a.get("passed") is True, (
        f"is_point_in_cone(Vector2(-50, 0)) should be false. Got: {a}"
    )


def test_detect_visible_player_in_range():
    results = _load_results()
    a = results["assertions"].get("detect_visible_in_range")
    assert a is not None, "Missing assertion: detect_visible_in_range"
    assert a.get("passed") is True, (
        f"detect() should return the player node when player is at (50, 0) with no wall. Got: {a}"
    )


def test_detect_returns_null_outside_range():
    results = _load_results()
    a = results["assertions"].get("detect_out_of_range")
    assert a is not None, "Missing assertion: detect_out_of_range"
    assert a.get("passed") is True, (
        f"detect() should return null when player is at (300, 0), outside range 200. Got: {a}"
    )


def test_detect_blocked_by_wall():
    results = _load_results()
    a = results["assertions"].get("detect_blocked_by_wall")
    assert a is not None, "Missing assertion: detect_blocked_by_wall"
    assert a.get("passed") is True, (
        f"detect() should return null when a wall blocks line-of-sight between enemy and player. Got: {a}"
    )


def test_target_spotted_emitted_once():
    results = _load_results()
    a = results["assertions"].get("target_spotted_emitted_once")
    assert a is not None, "Missing assertion: target_spotted_emitted_once"
    assert a.get("passed") is True, (
        f"target_spotted should be emitted exactly once on transition. Got: {a}"
    )
