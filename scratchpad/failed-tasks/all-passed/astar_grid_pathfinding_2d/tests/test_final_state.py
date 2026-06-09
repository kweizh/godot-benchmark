import json
import os
import subprocess
import textwrap

PROJECT_DIR = "/home/user/myproject"
LEVEL_PATH = os.path.join(PROJECT_DIR, "levels", "test_level.json")
SCRIPT_PATH = os.path.join(PROJECT_DIR, "scripts", "AStarGridPathfinder.gd")
HARNESS_PATH = os.path.join(PROJECT_DIR, "zealt_harness.gd")

EXPECTED_SIZE = [8, 8]
EXPECTED_SOLID = {(3, 1), (3, 2), (3, 3), (3, 4), (3, 5), (3, 6)}


HARNESS_SCRIPT = textwrap.dedent(
    """
    extends SceneTree

    const LEVEL_PATH := "res://levels/test_level.json"

    var _solid_set: Dictionary = {}
    var _pf = null

    func _fail(msg: String) -> void:
        print("ZEALT_RESULT: FAIL " + msg)
        quit(1)

    func _ok() -> void:
        print("ZEALT_RESULT: OK")
        quit(0)

    func _load_solid_set() -> bool:
        var f := FileAccess.open(LEVEL_PATH, FileAccess.READ)
        if f == null:
            _fail("could not open " + LEVEL_PATH)
            return false
        var raw := f.get_as_text()
        var parsed = JSON.parse_string(raw)
        if typeof(parsed) != TYPE_DICTIONARY:
            _fail("level json did not parse as dictionary")
            return false
        var solid_arr = parsed.get("solid", [])
        for s in solid_arr:
            var key := Vector2i(int(s[0]), int(s[1]))
            _solid_set[key] = true
        return true

    func _check_endpoints(path: PackedVector2Array, from_v: Vector2i, to_v: Vector2i, name: String) -> bool:
        if path.size() == 0:
            _fail(name + ": path is empty, expected non-empty")
            return false
        var first: Vector2 = path[0]
        var last: Vector2 = path[path.size() - 1]
        if int(round(first.x)) != from_v.x or int(round(first.y)) != from_v.y:
            _fail(name + ": path[0]=" + str(first) + " expected " + str(from_v))
            return false
        if int(round(last.x)) != to_v.x or int(round(last.y)) != to_v.y:
            _fail(name + ": path[-1]=" + str(last) + " expected " + str(to_v))
            return false
        return true

    func _check_no_solid(path: PackedVector2Array, name: String) -> bool:
        for p in path:
            var key := Vector2i(int(round(p.x)), int(round(p.y)))
            if _solid_set.has(key):
                _fail(name + ": path crosses solid cell " + str(key))
                return false
        return true

    func _check_orthogonal_steps(path: PackedVector2Array, name: String) -> bool:
        for i in range(1, path.size()):
            var dx: int = absi(int(round(path[i].x)) - int(round(path[i - 1].x)))
            var dy: int = absi(int(round(path[i].y)) - int(round(path[i - 1].y)))
            if dx + dy != 1:
                _fail(name + ": non-orthogonal step from " + str(path[i - 1]) + " to " + str(path[i]))
                return false
        return true

    func _check_adjacent_steps(path: PackedVector2Array, name: String) -> bool:
        for i in range(1, path.size()):
            var dx: int = absi(int(round(path[i].x)) - int(round(path[i - 1].x)))
            var dy: int = absi(int(round(path[i].y)) - int(round(path[i - 1].y)))
            var mx: int = maxi(dx, dy)
            if mx != 1 or (dx == 0 and dy == 0):
                _fail(name + ": non-adjacent step from " + str(path[i - 1]) + " to " + str(path[i]))
                return false
        return true

    func _path_contains(path: PackedVector2Array, p: Vector2i) -> bool:
        for v in path:
            if int(round(v.x)) == p.x and int(round(v.y)) == p.y:
                return true
        return false

    func _init() -> void:
        var script = load("res://scripts/AStarGridPathfinder.gd")
        if script == null:
            _fail("failed to load res://scripts/AStarGridPathfinder.gd")
            return
        var class_name_str: String = script.get_global_name()
        if class_name_str != "AStarGridPathfinder":
            _fail("script global class_name is '" + class_name_str + "', expected 'AStarGridPathfinder'")
            return
        var pf = script.new()
        if pf == null:
            _fail("failed to instantiate AStarGridPathfinder")
            return
        _pf = pf

        for method_name in ["load_level", "set_solid", "set_weight", "set_diagonal_mode", "set_heuristic", "find_path"]:
            if not pf.has_method(method_name):
                _fail("AStarGridPathfinder missing method '" + method_name + "'")
                return

        pf.load_level(LEVEL_PATH)

        if not _load_solid_set():
            return

        # ---- Test 1: NEVER + MANHATTAN, (0,3) -> (2,3) ----
        pf.set_diagonal_mode(1)
        pf.set_heuristic(1)
        var p1: PackedVector2Array = pf.find_path(Vector2i(0, 3), Vector2i(2, 3))
        if not _check_endpoints(p1, Vector2i(0, 3), Vector2i(2, 3), "T1"):
            return
        if not _check_orthogonal_steps(p1, "T1"):
            return
        if not _check_no_solid(p1, "T1"):
            return
        if p1.size() != 3:
            _fail("T1: expected path length 3, got " + str(p1.size()) + " path=" + str(p1))
            return

        # ---- Test 2: NEVER + MANHATTAN, (0,3) -> (5,3) ----
        var p2: PackedVector2Array = pf.find_path(Vector2i(0, 3), Vector2i(5, 3))
        if not _check_endpoints(p2, Vector2i(0, 3), Vector2i(5, 3), "T2"):
            return
        if not _check_orthogonal_steps(p2, "T2"):
            return
        if not _check_no_solid(p2, "T2"):
            return
        if p2.size() != 12:
            _fail("T2: expected path length 12, got " + str(p2.size()) + " path=" + str(p2))
            return

        # ---- Test 3: ALWAYS + OCTILE, (0,3) -> (5,3) ----
        pf.set_diagonal_mode(0)
        pf.set_heuristic(2)
        var p3: PackedVector2Array = pf.find_path(Vector2i(0, 3), Vector2i(5, 3))
        if not _check_endpoints(p3, Vector2i(0, 3), Vector2i(5, 3), "T3"):
            return
        if not _check_adjacent_steps(p3, "T3"):
            return
        if not _check_no_solid(p3, "T3"):
            return
        if p3.size() != 7:
            _fail("T3: expected path length 7, got " + str(p3.size()) + " path=" + str(p3))
            return

        # ---- Test 4: ALWAYS + EUCLIDEAN, (0,3) -> (5,3) ----
        pf.set_heuristic(0)
        var p4: PackedVector2Array = pf.find_path(Vector2i(0, 3), Vector2i(5, 3))
        if not _check_endpoints(p4, Vector2i(0, 3), Vector2i(5, 3), "T4"):
            return
        if not _check_adjacent_steps(p4, "T4"):
            return
        if not _check_no_solid(p4, "T4"):
            return
        if p4.size() != 7:
            _fail("T4: expected path length 7, got " + str(p4.size()) + " path=" + str(p4))
            return

        # ---- Test 5: NEVER + MANHATTAN, weight at (1,3) forces detour ----
        pf.set_diagonal_mode(1)
        pf.set_heuristic(1)
        pf.set_weight(1, 3, 100.0)
        var p5: PackedVector2Array = pf.find_path(Vector2i(0, 3), Vector2i(2, 3))
        if not _check_endpoints(p5, Vector2i(0, 3), Vector2i(2, 3), "T5"):
            return
        if not _check_orthogonal_steps(p5, "T5"):
            return
        if not _check_no_solid(p5, "T5"):
            return
        if p5.size() != 5:
            _fail("T5: expected path length 5, got " + str(p5.size()) + " path=" + str(p5))
            return
        if _path_contains(p5, Vector2i(1, 3)):
            _fail("T5: path should avoid weighted cell (1,3) but contains it: " + str(p5))
            return

        # Restore the weight so the next test starts from a clean state.
        pf.set_weight(1, 3, 1.0)

        # ---- Test 6: solid goal yields empty path ----
        pf.set_solid(5, 3, true)
        var p6: PackedVector2Array = pf.find_path(Vector2i(0, 3), Vector2i(5, 3))
        if p6.size() != 0:
            _fail("T6: expected empty path when goal is solid, got size " + str(p6.size()) + " path=" + str(p6))
            return
        pf.set_solid(5, 3, false)

        _ok()
    """
).strip() + "\n"


def _run_godot(args: list[str], timeout: int = 180) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["godot", "--headless", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=PROJECT_DIR,
    )


def test_script_file_exists():
    assert os.path.isfile(SCRIPT_PATH), (
        f"Required GDScript missing at {SCRIPT_PATH}; the agent must create "
        f"scripts/AStarGridPathfinder.gd."
    )


def test_level_json_unchanged():
    with open(LEVEL_PATH) as f:
        data = json.load(f)
    assert data.get("size") == EXPECTED_SIZE, (
        f"level json size changed; expected {EXPECTED_SIZE}, got {data.get('size')!r}"
    )
    actual_solid = {tuple(pair) for pair in data.get("solid", [])}
    assert actual_solid == EXPECTED_SOLID, (
        f"level json solid set changed; expected {EXPECTED_SOLID}, got {actual_solid}"
    )
    assert data.get("weights") == [], (
        f"level json weights changed; expected [], got {data.get('weights')!r}"
    )


def test_project_imports_cleanly():
    result = _run_godot(["--path", PROJECT_DIR, "--import"], timeout=180)
    assert result.returncode == 0, (
        f"`godot --headless --import` failed (exit {result.returncode}).\n"
        f"stdout:\n{result.stdout}\n"
        f"stderr:\n{result.stderr}"
    )


def test_pathfinder_harness_passes():
    with open(HARNESS_PATH, "w") as f:
        f.write(HARNESS_SCRIPT)

    try:
        result = _run_godot(
            ["--path", PROJECT_DIR, "--script", "res://zealt_harness.gd"],
            timeout=240,
        )
    finally:
        try:
            os.remove(HARNESS_PATH)
        except OSError:
            pass

    combined = (result.stdout or "") + "\n" + (result.stderr or "")
    assert "ZEALT_RESULT: OK" in combined, (
        f"AStarGridPathfinder harness did not report success.\n"
        f"exit code: {result.returncode}\n"
        f"stdout:\n{result.stdout}\n"
        f"stderr:\n{result.stderr}"
    )
    assert result.returncode == 0, (
        f"Harness exited with non-zero status {result.returncode}.\n"
        f"stdout:\n{result.stdout}\n"
        f"stderr:\n{result.stderr}"
    )
