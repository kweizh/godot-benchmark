import json
import os
import re
import subprocess

import pytest

PROJECT_DIR = "/home/user/myproject"

REQUIRED_CLASS_NAMES = [
    "BTNode",
    "BTSelector",
    "BTSequence",
    "BTInverter",
    "BTAction",
    "IsHealthy",
    "FleeAction",
    "PatrolUntilSpotted",
    "ChasePlayer",
    "AttackIfInRange",
    "BTFactory",
]

PROBE_SCRIPT = r"""extends SceneTree

func _init():
    var required := [
        "BTNode", "BTSelector", "BTSequence", "BTInverter", "BTAction",
        "IsHealthy", "FleeAction", "PatrolUntilSpotted", "ChasePlayer",
        "AttackIfInRange", "BTFactory"
    ]
    var registered := {}
    for entry in ProjectSettings.get_global_class_list():
        registered[entry["class"]] = true
    var report := {}
    for name in required:
        report[name] = registered.has(name)
    print("PROBE:" + JSON.stringify(report))
    quit()
"""

RUNNER_SCRIPT = r"""extends SceneTree

func _record(records: Array, label: String, status: int, blackboard: Dictionary) -> void:
    var snapshot := {}
    for key in blackboard.keys():
        snapshot[key] = blackboard[key]
    records.append({"label": label, "status": status, "blackboard": snapshot})

func _init():
    var records: Array = []
    var tree: BTNode = BTFactory.build_enemy_tree()

    # Scenario A: low-health flee
    var bb_a := {
        "health": 20,
        "healthy_threshold": 50,
        "player_spotted": false,
        "distance_to_player": 100,
        "attack_range": 10,
        "chase_speed": 30,
        "attack_damage": 5,
        "patrol_steps": 0,
    }
    var status_a1: int = tree.tick(bb_a)
    _record(records, "A1", status_a1, bb_a)

    # Scenario B: healthy patrol then spotted then chase then attack
    var bb_b := {
        "health": 80,
        "healthy_threshold": 50,
        "player_spotted": false,
        "distance_to_player": 40,
        "attack_range": 10,
        "chase_speed": 30,
        "attack_damage": 5,
        "patrol_steps": 0,
    }
    var status_b1: int = tree.tick(bb_b)
    _record(records, "B1", status_b1, bb_b)
    var status_b2: int = tree.tick(bb_b)
    _record(records, "B2", status_b2, bb_b)
    bb_b["player_spotted"] = true
    var status_b3: int = tree.tick(bb_b)
    _record(records, "B3", status_b3, bb_b)
    var status_b4: int = tree.tick(bb_b)
    _record(records, "B4", status_b4, bb_b)

    # Scenario C: combat then mid-fight health drop
    var bb_c := {
        "health": 80,
        "healthy_threshold": 50,
        "player_spotted": true,
        "distance_to_player": 5,
        "attack_range": 10,
        "chase_speed": 30,
        "attack_damage": 5,
        "patrol_steps": 0,
    }
    var status_c1: int = tree.tick(bb_c)
    _record(records, "C1", status_c1, bb_c)
    bb_c["health"] = 20
    var status_c2: int = tree.tick(bb_c)
    _record(records, "C2", status_c2, bb_c)

    print("BT_RESULTS:" + JSON.stringify(records))
    quit()
"""


def _write_helper(rel_path: str, content: str) -> str:
    full = os.path.join(PROJECT_DIR, rel_path)
    with open(full, "w", encoding="utf-8") as fh:
        fh.write(content)
    return full


def _remove_if_exists(rel_path: str) -> None:
    full = os.path.join(PROJECT_DIR, rel_path)
    if os.path.exists(full):
        os.remove(full)


def _run_godot_script(script_res_path: str, timeout: int = 180) -> subprocess.CompletedProcess:
    return subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "--script",
            script_res_path,
        ],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


_IMPORT_DONE = False


def _ensure_project_imported() -> None:
    """Force Godot to scan the project so that `class_name` identifiers are
    registered in `ProjectSettings.get_global_class_list()`.

    Running `godot --headless --editor --quit` triggers a one-shot editor scan
    that populates `.godot/global_script_class_cache.cfg`.
    """
    global _IMPORT_DONE
    if _IMPORT_DONE:
        return
    subprocess.run(
        ["godot", "--headless", "--editor", "--quit", "--path", PROJECT_DIR],
        capture_output=True,
        text=True,
        timeout=180,
    )
    _IMPORT_DONE = True


def _extract_prefixed_json(output: str, prefix: str):
    pattern = re.compile(r"^" + re.escape(prefix) + r"(.*)$", re.MULTILINE)
    match = pattern.search(output)
    assert match is not None, (
        f"Could not find a line starting with '{prefix}' in godot output:\n{output}"
    )
    raw = match.group(1).strip()
    return json.loads(raw)


@pytest.fixture(scope="module")
def probe_result():
    _ensure_project_imported()
    _remove_if_exists("zealt_bt_probe.gd")
    _write_helper("zealt_bt_probe.gd", PROBE_SCRIPT)
    result = _run_godot_script("res://zealt_bt_probe.gd")
    combined = (result.stdout or "") + "\n" + (result.stderr or "")
    assert result.returncode == 0, (
        f"Probe godot run failed with exit code {result.returncode}:\n{combined}"
    )
    report = _extract_prefixed_json(combined, "PROBE:")
    yield report


@pytest.fixture(scope="module")
def runner_result():
    _ensure_project_imported()
    _remove_if_exists("zealt_bt_runner.gd")
    _write_helper("zealt_bt_runner.gd", RUNNER_SCRIPT)
    result = _run_godot_script("res://zealt_bt_runner.gd")
    combined = (result.stdout or "") + "\n" + (result.stderr or "")
    assert result.returncode == 0, (
        f"Runner godot run failed with exit code {result.returncode}:\n{combined}"
    )
    records = _extract_prefixed_json(combined, "BT_RESULTS:")
    assert isinstance(records, list), (
        f"Expected BT_RESULTS to decode to a list, got {type(records).__name__}: {records!r}"
    )
    by_label = {entry["label"]: entry for entry in records}
    yield records, by_label, combined


@pytest.mark.parametrize("class_name", REQUIRED_CLASS_NAMES)
def test_required_class_names_registered(probe_result, class_name: str):
    assert probe_result.get(class_name) is True, (
        f"Required class_name '{class_name}' was not found in ProjectSettings.get_global_class_list()."
    )


def test_runner_records_have_all_labels(runner_result):
    _records, by_label, combined = runner_result
    expected_labels = ["A1", "B1", "B2", "B3", "B4", "C1", "C2"]
    missing = [lbl for lbl in expected_labels if lbl not in by_label]
    assert not missing, (
        f"BT_RESULTS is missing labels {missing}. Full driver output:\n{combined}"
    )


def test_scenario_a_low_health_flees(runner_result):
    _records, by_label, _combined = runner_result
    a1 = by_label["A1"]
    assert a1["status"] == 0, f"A1 expected status SUCCESS(0), got {a1['status']}"
    bb = a1["blackboard"]
    assert bb.get("action") == "flee", f"A1 expected action 'flee', got {bb.get('action')!r}"
    assert bb.get("patrol_steps") == 0, (
        f"A1 must not advance patrol_steps when fleeing, got {bb.get('patrol_steps')!r}"
    )
    assert bb.get("distance_to_player") == 100, (
        f"A1 must not change distance_to_player, got {bb.get('distance_to_player')!r}"
    )
    assert "last_attack_damage" not in bb, (
        f"A1 must not record an attack, but last_attack_damage was present: {bb}"
    )


def test_scenario_b_patrol_and_engage(runner_result):
    _records, by_label, _combined = runner_result

    b1 = by_label["B1"]
    assert b1["status"] == 2, f"B1 expected RUNNING(2), got {b1['status']}"
    assert b1["blackboard"].get("patrol_steps") == 1, (
        f"B1 expected patrol_steps==1, got {b1['blackboard'].get('patrol_steps')!r}"
    )
    assert b1["blackboard"].get("action") == "patrol", (
        f"B1 expected action 'patrol', got {b1['blackboard'].get('action')!r}"
    )
    assert b1["blackboard"].get("distance_to_player") == 40, (
        f"B1 must not change distance_to_player during patrol, got {b1['blackboard'].get('distance_to_player')!r}"
    )

    b2 = by_label["B2"]
    assert b2["status"] == 2, f"B2 expected RUNNING(2), got {b2['status']}"
    assert b2["blackboard"].get("patrol_steps") == 2, (
        f"B2 expected patrol_steps==2, got {b2['blackboard'].get('patrol_steps')!r}"
    )
    assert b2["blackboard"].get("action") == "patrol", (
        f"B2 expected action 'patrol', got {b2['blackboard'].get('action')!r}"
    )

    b3 = by_label["B3"]
    assert b3["status"] == 2, f"B3 expected RUNNING(2), got {b3['status']}"
    assert b3["blackboard"].get("action") == "chase", (
        f"B3 expected action 'chase' after being spotted and chasing, got {b3['blackboard'].get('action')!r}"
    )
    assert b3["blackboard"].get("distance_to_player") == 10, (
        f"B3 expected distance_to_player==10 after one chase step (40-30), got {b3['blackboard'].get('distance_to_player')!r}"
    )
    assert b3["blackboard"].get("patrol_steps") == 2, (
        f"B3 must not advance patrol_steps after being spotted, got {b3['blackboard'].get('patrol_steps')!r}"
    )

    b4 = by_label["B4"]
    assert b4["status"] == 0, f"B4 expected SUCCESS(0), got {b4['status']}"
    assert b4["blackboard"].get("action") == "attack", (
        f"B4 expected action 'attack' once in range, got {b4['blackboard'].get('action')!r}"
    )
    assert b4["blackboard"].get("distance_to_player") == 10, (
        f"B4 expected distance_to_player==10 (already in range), got {b4['blackboard'].get('distance_to_player')!r}"
    )
    assert b4["blackboard"].get("last_attack_damage") == 5, (
        f"B4 expected last_attack_damage==5, got {b4['blackboard'].get('last_attack_damage')!r}"
    )


def test_scenario_c_health_drop_forces_flee(runner_result):
    _records, by_label, _combined = runner_result

    c1 = by_label["C1"]
    assert c1["status"] == 0, f"C1 expected SUCCESS(0), got {c1['status']}"
    assert c1["blackboard"].get("action") == "attack", (
        f"C1 expected action 'attack', got {c1['blackboard'].get('action')!r}"
    )
    assert c1["blackboard"].get("last_attack_damage") == 5, (
        f"C1 expected last_attack_damage==5, got {c1['blackboard'].get('last_attack_damage')!r}"
    )
    assert c1["blackboard"].get("distance_to_player") == 5, (
        f"C1 expected distance_to_player==5 (already in range), got {c1['blackboard'].get('distance_to_player')!r}"
    )

    c2 = by_label["C2"]
    assert c2["status"] == 0, f"C2 expected SUCCESS(0), got {c2['status']}"
    assert c2["blackboard"].get("action") == "flee", (
        f"C2 expected action 'flee' after health drop, got {c2['blackboard'].get('action')!r}"
    )
    assert c2["blackboard"].get("distance_to_player") == 5, (
        f"C2 must not change distance_to_player when fleeing, got {c2['blackboard'].get('distance_to_player')!r}"
    )
    assert c2["blackboard"].get("last_attack_damage") == 5, (
        f"C2 must preserve prior last_attack_damage from C1, got {c2['blackboard'].get('last_attack_damage')!r}"
    )


def test_runner_is_deterministic():
    _ensure_project_imported()
    # Re-run the driver and ensure byte-identical BT_RESULTS payload.
    result1 = _run_godot_script("res://zealt_bt_runner.gd")
    out1 = (result1.stdout or "") + "\n" + (result1.stderr or "")
    assert result1.returncode == 0, f"Determinism run 1 failed:\n{out1}"
    payload1 = _extract_prefixed_json(out1, "BT_RESULTS:")

    result2 = _run_godot_script("res://zealt_bt_runner.gd")
    out2 = (result2.stdout or "") + "\n" + (result2.stderr or "")
    assert result2.returncode == 0, f"Determinism run 2 failed:\n{out2}"
    payload2 = _extract_prefixed_json(out2, "BT_RESULTS:")

    assert json.dumps(payload1, sort_keys=True) == json.dumps(payload2, sort_keys=True), (
        "Behavior tree driver was not deterministic across runs.\n"
        f"Run 1: {payload1}\nRun 2: {payload2}"
    )
