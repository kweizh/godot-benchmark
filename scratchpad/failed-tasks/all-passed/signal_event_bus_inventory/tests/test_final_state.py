import json
import os
import re
import subprocess
import textwrap

import pytest

PROJECT_DIR = "/home/user/myproject"
HARNESS_DIR = os.path.join(PROJECT_DIR, "tests")
HARNESS_SCENE = os.path.join(HARNESS_DIR, "harness.tscn")
HARNESS_SCRIPT = os.path.join(HARNESS_DIR, "harness.gd")
HARNESS_OUTPUT = "/tmp/harness_output.json"

HARNESS_GD = r"""
extends Node

const OUTPUT_PATH := "/tmp/harness_output.json"

func _ready() -> void:
    var result := await _run()
    var f := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
    f.store_string(JSON.stringify(result))
    f.close()
    get_tree().quit()

func _disconnect_all(sig: Signal) -> void:
    for c in sig.get_connections():
        sig.disconnect(c["callable"])

func _run() -> Dictionary:
    var details: Dictionary = {}
    var ok: bool = true

    var bus = get_node_or_null("/root/EventBus")
    if bus == null:
        details["eventbus_missing"] = true
        return {"ok": false, "details": details}

    var required := {
        "item_picked_up": ["item_id", "quantity"],
        "item_used": ["item_id"],
        "inventory_changed": ["snapshot"],
        "inventory_full": []
    }
    var sig_arg_map := {}
    for s in bus.get_signal_list():
        var names: Array = []
        for a in s["args"]:
            names.append(a["name"])
        sig_arg_map[s["name"]] = names
    for sig_name in required.keys():
        if not bus.has_signal(sig_name):
            details["missing_signal_" + String(sig_name)] = true
            ok = false
            continue
        var expected = required[sig_name]
        var actual = sig_arg_map.get(sig_name, [])
        if actual != expected:
            details["bad_signal_args_" + String(sig_name)] = {
                "expected": expected, "actual": actual
            }
            ok = false
    if not ok:
        return {"ok": false, "details": details}

    var InventoryScript = load("res://scripts/Inventory.gd")
    if InventoryScript == null:
        details["inventory_script_missing"] = true
        return {"ok": false, "details": details}

    # ---- Test 1: Accumulation ----
    var inv1 = InventoryScript.new()
    if "max_slots" in inv1:
        inv1.max_slots = 8
    add_child(inv1)
    await get_tree().process_frame

    var captured1: Array = []
    var cb1 := func(snap): captured1.append(snap.duplicate(true) if snap is Dictionary else snap)
    bus.inventory_changed.connect(cb1)

    bus.item_picked_up.emit(StringName("potion"), 2)
    await get_tree().process_frame
    bus.item_picked_up.emit(StringName("potion"), 3)
    await get_tree().process_frame

    if captured1.is_empty():
        details["accumulation_no_emit"] = true
        ok = false
    else:
        var final_snap = captured1[-1]
        if not (final_snap is Dictionary):
            details["snapshot_not_dictionary"] = typeof(final_snap)
            ok = false
        else:
            var val = -1
            if final_snap.has(StringName("potion")):
                val = final_snap[StringName("potion")]
            elif final_snap.has("potion"):
                val = final_snap["potion"]
            if val != 5:
                details["accumulation_fail"] = {"snap_keys": final_snap.keys(), "snap_values": final_snap.values()}
                ok = false

    _disconnect_all(bus.inventory_changed)
    inv1.queue_free()
    await get_tree().process_frame

    # ---- Test 2: Overflow ----
    var inv2 = InventoryScript.new()
    if "max_slots" in inv2:
        inv2.max_slots = 4
    add_child(inv2)
    await get_tree().process_frame

    var captured2: Array = []
    var full_count: Array = [0]
    var cb2 := func(snap): captured2.append(snap.duplicate(true) if snap is Dictionary else snap)
    var cb_full := func(): full_count[0] += 1
    bus.inventory_changed.connect(cb2)
    bus.inventory_full.connect(cb_full)

    for i in range(5):
        bus.item_picked_up.emit(StringName("item_" + str(i)), 1)
        await get_tree().process_frame

    if full_count[0] < 1:
        details["inventory_full_not_emitted"] = true
        ok = false
    if captured2.is_empty():
        details["overflow_no_snapshot"] = true
        ok = false
    else:
        var last_snap = captured2[-1]
        if not (last_snap is Dictionary) or last_snap.size() != 4:
            details["overflow_snapshot_size"] = (last_snap.size() if last_snap is Dictionary else -1)
            ok = false

    _disconnect_all(bus.inventory_changed)
    _disconnect_all(bus.inventory_full)
    inv2.queue_free()
    await get_tree().process_frame

    # ---- Test 3: Hotbar ----
    var inv3 = InventoryScript.new()
    if "max_slots" in inv3:
        inv3.max_slots = 8
    add_child(inv3)
    await get_tree().process_frame

    var HotbarScene = load("res://scenes/Hotbar.tscn")
    if HotbarScene == null:
        details["hotbar_scene_missing"] = true
        return {"ok": false, "details": details}
    var hotbar = HotbarScene.instantiate()
    add_child(hotbar)
    await get_tree().process_frame
    await get_tree().process_frame

    bus.item_picked_up.emit(StringName("potion"), 5)
    await get_tree().process_frame
    await get_tree().process_frame

    var first_label: Label = null
    for child in hotbar.get_children():
        if child is Label:
            first_label = child
            break
    if first_label == null:
        details["hotbar_no_label_child"] = true
        ok = false
    else:
        var regex := RegEx.new()
        regex.compile("^&?potion x5$")
        if regex.search(first_label.text) == null:
            details["hotbar_label_text"] = first_label.text
            ok = false
        if not first_label.visible:
            details["hotbar_label_not_visible"] = true
            ok = false

    return {"ok": ok, "details": details}
"""

HARNESS_TSCN = """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/harness.gd" id="1"]

[node name="Harness" type="Node"]
script = ExtResource("1")
"""


@pytest.fixture(scope="module", autouse=True)
def install_harness():
    os.makedirs(HARNESS_DIR, exist_ok=True)
    with open(HARNESS_SCRIPT, "w") as f:
        f.write(HARNESS_GD)
    with open(HARNESS_SCENE, "w") as f:
        f.write(HARNESS_TSCN)
    if os.path.exists(HARNESS_OUTPUT):
        os.remove(HARNESS_OUTPUT)
    yield


def _read_text(path: str) -> str:
    with open(path, "r") as f:
        return f.read()


def test_required_files_exist():
    required = [
        "project.godot",
        "autoloads/EventBus.gd",
        "scripts/Inventory.gd",
        "scenes/Pickup.tscn",
        "scenes/Hotbar.tscn",
    ]
    for rel in required:
        path = os.path.join(PROJECT_DIR, rel)
        assert os.path.isfile(path), f"Required file missing: {path}"


def test_project_godot_registers_eventbus_autoload():
    content = _read_text(os.path.join(PROJECT_DIR, "project.godot"))
    assert "[autoload]" in content, (
        "project.godot is missing an [autoload] section."
    )
    m = re.search(
        r"^EventBus\s*=\s*\"\*?res://autoloads/EventBus\.gd\"",
        content,
        re.MULTILINE,
    )
    assert m is not None, (
        "project.godot does not register EventBus autoload pointing at "
        "res://autoloads/EventBus.gd. project.godot contents:\n" + content
    )


def test_inventory_script_does_not_reference_inventory_or_hotbar_names():
    path = os.path.join(PROJECT_DIR, "scripts/Inventory.gd")
    content = _read_text(path)
    # Strip class_name declaration line so the file may still declare itself.
    stripped = "\n".join(
        line for line in content.splitlines()
        if not line.strip().startswith("class_name")
    )
    assert "Inventory." not in stripped, (
        "scripts/Inventory.gd must not reference 'Inventory.' directly "
        "(decoupling violation)."
    )
    assert "Hotbar." not in stripped, (
        "scripts/Inventory.gd must not reference 'Hotbar.' directly "
        "(decoupling violation)."
    )


def _collect_pickup_script_text() -> str:
    """Return the text of the Pickup script. Search common locations."""
    candidates = [
        os.path.join(PROJECT_DIR, "scripts/Pickup.gd"),
        os.path.join(PROJECT_DIR, "scenes/Pickup.gd"),
    ]
    text_parts: list[str] = []
    for p in candidates:
        if os.path.isfile(p):
            text_parts.append(_read_text(p))
    tscn = _read_text(os.path.join(PROJECT_DIR, "scenes/Pickup.tscn"))
    text_parts.append(tscn)
    # Also follow any ext_resource Script reference inside the .tscn
    for m in re.finditer(r'ext_resource\s+type="Script"\s+path="res://([^"]+)"', tscn):
        rel = m.group(1)
        absp = os.path.join(PROJECT_DIR, rel)
        if os.path.isfile(absp):
            text_parts.append(_read_text(absp))
    return "\n".join(text_parts)


def test_pickup_script_does_not_reference_inventory_or_hotbar_names():
    content = _collect_pickup_script_text()
    stripped = "\n".join(
        line for line in content.splitlines()
        if not line.strip().startswith("class_name")
    )
    assert "Inventory." not in stripped, (
        "Pickup script must not reference 'Inventory.' directly "
        "(decoupling violation)."
    )
    assert "Hotbar." not in stripped, (
        "Pickup script must not reference 'Hotbar.' directly "
        "(decoupling violation)."
    )


@pytest.fixture(scope="module")
def harness_result():
    # Import the project once to materialise .godot/ caches.
    subprocess.run(
        ["godot", "--headless", "--path", PROJECT_DIR, "--quit"],
        capture_output=True,
        text=True,
        timeout=120,
    )
    result = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "res://tests/harness.tscn",
        ],
        capture_output=True,
        text=True,
        timeout=180,
    )
    assert os.path.isfile(HARNESS_OUTPUT), (
        f"Harness did not produce {HARNESS_OUTPUT}.\n"
        f"rc={result.returncode}\nstdout={result.stdout}\nstderr={result.stderr}"
    )
    with open(HARNESS_OUTPUT, "r") as f:
        data = json.load(f)
    return data, result


def test_harness_overall_ok(harness_result):
    data, proc = harness_result
    details = data.get("details", {})
    assert data.get("ok") is True, (
        "Harness reported failure. "
        f"details={details}\nstdout={proc.stdout}\nstderr={proc.stderr}"
    )


def test_harness_signal_signatures_ok(harness_result):
    data, _ = harness_result
    details = data.get("details", {})
    bad_keys = [
        k for k in details
        if k.startswith("missing_signal_") or k.startswith("bad_signal_args_")
    ]
    assert not bad_keys, (
        f"EventBus signal signatures are wrong: "
        f"{ {k: details[k] for k in bad_keys} }"
    )


def test_harness_accumulation_ok(harness_result):
    data, _ = harness_result
    details = data.get("details", {})
    assert "accumulation_fail" not in details, (
        f"Accumulation check failed: {details.get('accumulation_fail')}"
    )
    assert "accumulation_no_emit" not in details, (
        "Inventory never emitted inventory_changed after pickup events."
    )


def test_harness_overflow_ok(harness_result):
    data, _ = harness_result
    details = data.get("details", {})
    assert "inventory_full_not_emitted" not in details, (
        "Inventory did not emit inventory_full when exceeding max_slots."
    )
    assert "overflow_snapshot_size" not in details, (
        "Snapshot after overflow did not contain exactly max_slots entries: "
        f"{details.get('overflow_snapshot_size')}"
    )


def test_harness_hotbar_label_ok(harness_result):
    data, _ = harness_result
    details = data.get("details", {})
    assert "hotbar_no_label_child" not in details, (
        "Hotbar scene has no Label child to display the first inventory slot."
    )
    assert "hotbar_label_text" not in details, (
        f"Hotbar first slot label text does not match '^&?potion x5$': "
        f"got {details.get('hotbar_label_text')!r}"
    )
    assert "hotbar_label_not_visible" not in details, (
        "Hotbar first slot label was not visible even though it had content."
    )


_ = textwrap  # silence unused-import linter if textwrap usage is removed later
