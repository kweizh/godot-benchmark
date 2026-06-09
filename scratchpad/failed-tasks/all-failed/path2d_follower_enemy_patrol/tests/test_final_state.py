import json
import math
import os
import re
import subprocess

import pytest

PROJECT_DIR = "/home/user/myproject"
SCENE_PATH = os.path.join(PROJECT_DIR, "scenes", "PatrolEnemy.tscn")
SCRIPT_PATH = os.path.join(PROJECT_DIR, "scripts", "PatrolController.gd")
WAYPOINTS_PATH = os.path.join(PROJECT_DIR, "data", "waypoints.json")
RUNNER_PATH = os.path.join(PROJECT_DIR, "test_runner.gd")

CANONICAL_WAYPOINTS = {
    "waypoints": [[0, 0], [300, 0], [300, 300], [0, 300]],
}

TOL = 0.01

# Test runner GDScript embedded as a Python string so it can be written into the
# executor's project at verification time. It extends SceneTree, runs four
# scenarios, prints META and RESULT lines on stdout, then quits.
#
# The runner awaits `process_frame` after every `add_child` so any `@onready`
# vars on the executor's controller are resolved before `tick()` is called.
TEST_RUNNER_GD = r"""extends SceneTree

func _initialize() -> void:
    _async_main()

func _on_progress(r: float, sink: Array) -> void:
    sink.append(r)

func _async_main() -> void:
    var packed := load("res://scenes/PatrolEnemy.tscn") as PackedScene
    if packed == null:
        print("FATAL::failed_to_load_scene")
        quit(1)
        return

    # Reflective sanity check on the controller API.
    var meta_scene = packed.instantiate()
    root.add_child(meta_scene)
    await self.process_frame
    var meta := {
        "has_progress_changed_signal": meta_scene.has_signal("progress_changed"),
        "has_load_waypoints": meta_scene.has_method("load_waypoints"),
        "has_set_mode": meta_scene.has_method("set_mode"),
        "has_set_speed": meta_scene.has_method("set_speed"),
        "has_set_direction": meta_scene.has_method("set_direction"),
        "has_tick": meta_scene.has_method("tick"),
        "has_path_follow_child": meta_scene.has_node("PathFollow2D"),
        "root_class": meta_scene.get_class(),
    }
    print("META::" + JSON.stringify(meta))
    meta_scene.queue_free()

    var scenarios := [
        {"name": "loop_forward_no_wrap", "mode": "loop",     "dir": 1,  "speed": 300.0, "dt": 0.1, "ticks": 10},
        {"name": "loop_forward_wrap",    "mode": "loop",     "dir": 1,  "speed": 300.0, "dt": 0.1, "ticks": 35},
        {"name": "pingpong_reverse",     "mode": "pingpong", "dir": 1,  "speed": 300.0, "dt": 0.1, "ticks": 35},
        {"name": "loop_reverse_wrap",    "mode": "loop",     "dir": -1, "speed": 300.0, "dt": 0.1, "ticks": 5},
    ]

    for s in scenarios:
        var inst = packed.instantiate()
        root.add_child(inst)
        # Wait one frame so @onready resolves before we drive the controller.
        await self.process_frame
        var sink: Array = []
        var cb := Callable(self, "_on_progress").bind(sink)
        if inst.has_signal("progress_changed"):
            inst.connect("progress_changed", cb)
        if inst.has_method("load_waypoints"):
            inst.call("load_waypoints", "res://data/waypoints.json")
        if inst.has_method("set_mode"):
            inst.call("set_mode", s["mode"])
        if inst.has_method("set_speed"):
            inst.call("set_speed", s["speed"])
        if inst.has_method("set_direction"):
            inst.call("set_direction", s["dir"])
        if inst.has_method("tick"):
            for _i in s["ticks"]:
                inst.call("tick", s["dt"])
        var ratio := 0.0
        if inst.has_node("PathFollow2D"):
            var pf := inst.get_node("PathFollow2D")
            ratio = pf.progress_ratio
        var out := {
            "name": s["name"],
            "ratio": ratio,
            "signals": sink,
        }
        print("RESULT::" + JSON.stringify(out))
        inst.queue_free()

    quit(0)
"""

EXPECTED = {
    "loop_forward_no_wrap": {
        "ratio": 1.0 / 3.0,
        "signals": [1.0 / 3.0],
    },
    "loop_forward_wrap": {
        "ratio": 150.0 / 900.0,  # 0.1667
        "signals": [1.0 / 3.0, 2.0 / 3.0, 1.0],
    },
    "pingpong_reverse": {
        "ratio": 750.0 / 900.0,  # 0.8333
        "signals": [1.0 / 3.0, 2.0 / 3.0, 1.0],
    },
    "loop_reverse_wrap": {
        "ratio": 750.0 / 900.0,  # 0.8333
        "signals": [0.0],
    },
}


def _close(a: float, b: float, tol: float = TOL) -> bool:
    return math.isfinite(a) and math.isfinite(b) and abs(a - b) <= tol


@pytest.fixture(scope="module")
def runner_output():
    # File-existence preconditions.
    assert os.path.isfile(SCRIPT_PATH), (
        f"Controller script {SCRIPT_PATH} was not created."
    )
    assert os.path.isfile(SCENE_PATH), (
        f"Scene file {SCENE_PATH} was not created."
    )
    assert os.path.isfile(WAYPOINTS_PATH), (
        f"Waypoints file {WAYPOINTS_PATH} is missing."
    )

    # Overwrite waypoints with the canonical test fixture so geometry is known.
    with open(WAYPOINTS_PATH, "w") as f:
        json.dump(CANONICAL_WAYPOINTS, f)

    # Drop the test runner into the project.
    with open(RUNNER_PATH, "w") as f:
        f.write(TEST_RUNNER_GD)

    # One-time headless import pass so Godot indexes scene/script resources.
    import_proc = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "--quit-after",
            "5",
        ],
        capture_output=True,
        text=True,
        timeout=120,
    )
    # Importing a code-only project may exit non-zero on some Godot builds;
    # we only care that the project can be opened. Any hard error will surface
    # when the runner itself runs below.
    _ = import_proc

    proc = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "-s",
            "res://test_runner.gd",
        ],
        capture_output=True,
        text=True,
        timeout=180,
    )

    assert proc.returncode == 0, (
        "Godot test runner exited with non-zero status: "
        f"code={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    )

    meta = None
    results = {}
    for line in proc.stdout.splitlines():
        line = line.strip()
        if line.startswith("META::"):
            meta = json.loads(line[len("META::"):])
        elif line.startswith("RESULT::"):
            payload = json.loads(line[len("RESULT::"):])
            results[payload["name"]] = payload
        elif line.startswith("FATAL::"):
            pytest.fail(
                "Test runner reported fatal error: "
                f"{line}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
            )

    assert meta is not None, (
        "Test runner did not print a META line. "
        f"stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    )
    assert results, (
        "Test runner did not print any RESULT lines. "
        f"stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    )
    return meta, results, proc


def test_controller_api_present(runner_output):
    meta, _results, _proc = runner_output
    assert meta.get("has_path_follow_child"), (
        "PatrolEnemy scene root does not have a child node named 'PathFollow2D'."
    )
    assert meta.get("has_progress_changed_signal"), (
        "PatrolController is missing the required signal 'progress_changed'."
    )
    for fn in ("has_load_waypoints", "has_set_mode", "has_set_speed", "has_set_direction", "has_tick"):
        assert meta.get(fn), (
            f"PatrolController is missing required method: {fn[len('has_'):]}"
        )
    root_class = meta.get("root_class", "")
    assert re.match(r"^Path2D$", root_class) is not None, (
        f"PatrolEnemy root node must be a Path2D, got class {root_class!r}."
    )


@pytest.mark.parametrize("name", list(EXPECTED.keys()))
def test_scenario_final_ratio(runner_output, name):
    _meta, results, proc = runner_output
    assert name in results, (
        f"Scenario {name!r} is missing from runner output. "
        f"stdout:\n{proc.stdout}"
    )
    actual = float(results[name]["ratio"])
    expected = float(EXPECTED[name]["ratio"])
    assert _close(actual, expected), (
        f"Scenario {name!r}: expected final progress_ratio ~ {expected:.4f} "
        f"(tol={TOL}), got {actual:.4f}."
    )


@pytest.mark.parametrize("name", list(EXPECTED.keys()))
def test_scenario_signal_sequence(runner_output, name):
    _meta, results, proc = runner_output
    assert name in results, (
        f"Scenario {name!r} is missing from runner output. "
        f"stdout:\n{proc.stdout}"
    )
    actual = [float(x) for x in results[name]["signals"]]
    expected = [float(x) for x in EXPECTED[name]["signals"]]
    assert len(actual) == len(expected), (
        f"Scenario {name!r}: expected {len(expected)} progress_changed "
        f"emissions {expected}, got {len(actual)} {actual}."
    )
    for i, (a, e) in enumerate(zip(actual, expected)):
        assert _close(a, e), (
            f"Scenario {name!r}: signal #{i} expected ~ {e:.4f} (tol={TOL}), "
            f"got {a:.4f}. Full sequence actual={actual} expected={expected}."
        )
