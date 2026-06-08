import json
import os
import re
import subprocess

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

func _approx(a: float, b: float, tol: float) -> bool:
    return abs(a - b) <= tol

func _wait(seconds: float) -> void:
    var t := 0.0
    while t < seconds:
        await get_tree().process_frame
        t += get_process_delta_time()

func _run() -> Dictionary:
    var details: Dictionary = {}
    var ok: bool = true

    # Check AudioManager autoload presence
    var mgr = get_node_or_null("/root/AudioManager")
    if mgr == null:
        details["audio_manager_missing"] = true
        return {"ok": false, "details": details}

    # Check bus count and names
    if AudioServer.bus_count < 4:
        details["bus_count_too_low"] = AudioServer.bus_count
        return {"ok": false, "details": details}

    var expected_names := ["master", "music", "sfx", "voice"]
    var actual_names: Array = []
    for i in range(min(4, AudioServer.bus_count)):
        actual_names.append(AudioServer.get_bus_name(i).to_lower())
    if actual_names != expected_names:
        details["bus_names_mismatch"] = {"expected": expected_names, "actual": actual_names}
        ok = false

    var music_idx := AudioServer.get_bus_index("Music")
    var sfx_idx := AudioServer.get_bus_index("SFX")
    var voice_idx := AudioServer.get_bus_index("Voice")
    if music_idx < 0 or sfx_idx < 0 or voice_idx < 0:
        details["bus_index_missing"] = {
            "music": music_idx, "sfx": sfx_idx, "voice": voice_idx
        }
        return {"ok": false, "details": details}

    # Check bus sends
    if AudioServer.get_bus_send(music_idx).to_lower() != "master":
        details["music_send_wrong"] = AudioServer.get_bus_send(music_idx)
        ok = false
    if AudioServer.get_bus_send(sfx_idx).to_lower() != "master":
        details["sfx_send_wrong"] = AudioServer.get_bus_send(sfx_idx)
        ok = false
    if AudioServer.get_bus_send(voice_idx).to_lower() != "master":
        details["voice_send_wrong"] = AudioServer.get_bus_send(voice_idx)
        ok = false

    # Check low pass effect on Music bus
    if AudioServer.get_bus_effect_count(music_idx) < 1:
        details["music_no_effects"] = true
        ok = false
    else:
        var eff = AudioServer.get_bus_effect(music_idx, 0)
        if not (eff is AudioEffectLowPassFilter):
            details["music_effect_wrong_type"] = str(eff.get_class()) if eff != null else "null"
            ok = false
        else:
            if AudioServer.is_bus_effect_enabled(music_idx, 0):
                details["music_lowpass_enabled_by_default"] = true
                ok = false

    if not ok:
        return {"ok": false, "details": details}

    # ---- Test: set_bus_volume + bus_volume_changed signal ----
    var captured_signals: Array = []
    if not mgr.has_signal("bus_volume_changed"):
        details["no_bus_volume_changed_signal"] = true
        return {"ok": false, "details": details}
    var cb := func(name, db): captured_signals.append([String(name).to_lower(), db])
    mgr.bus_volume_changed.connect(cb)

    mgr.set_bus_volume(&"Music", -6.0)
    await get_tree().process_frame
    var measured := AudioServer.get_bus_volume_db(music_idx)
    if not _approx(measured, -6.0, 0.01):
        details["set_volume_audioserver_mismatch"] = measured
        ok = false
    var got_sig := false
    for s in captured_signals:
        if s[0] == "music" and _approx(float(s[1]), -6.0, 0.01):
            got_sig = true
            break
    if not got_sig:
        details["signal_not_emitted"] = captured_signals
        ok = false

    var got_vol = mgr.get_bus_volume(&"Music")
    if not _approx(float(got_vol), -6.0, 0.01):
        details["get_bus_volume_mismatch"] = got_vol
        ok = false

    # ---- Test: mute_bus ----
    mgr.mute_bus(&"SFX", true)
    await get_tree().process_frame
    if not AudioServer.is_bus_mute(sfx_idx):
        details["mute_true_failed"] = true
        ok = false
    mgr.mute_bus(&"SFX", false)
    await get_tree().process_frame
    if AudioServer.is_bus_mute(sfx_idx):
        details["mute_false_failed"] = true
        ok = false

    # ---- Test: low pass toggle ----
    mgr.set_low_pass_enabled(true)
    await get_tree().process_frame
    if not AudioServer.is_bus_effect_enabled(music_idx, 0):
        details["lowpass_enable_failed"] = true
        ok = false
    mgr.set_low_pass_enabled(false)
    await get_tree().process_frame
    if AudioServer.is_bus_effect_enabled(music_idx, 0):
        details["lowpass_disable_failed"] = true
        ok = false

    # ---- Test: duck_music ----
    mgr.set_bus_volume(&"Music", 0.0)
    await get_tree().process_frame
    var original := AudioServer.get_bus_volume_db(music_idx)
    if not _approx(original, 0.0, 0.01):
        details["reset_to_zero_failed"] = original
        ok = false

    mgr.duck_music(-10.0, 0.05)
    # Allow tween a frame to apply
    await get_tree().process_frame
    await get_tree().process_frame
    var after_duck := AudioServer.get_bus_volume_db(music_idx)
    if after_duck > -8.0:
        details["duck_did_not_drop"] = after_duck
        ok = false

    # Wait for restore
    await _wait(0.5)
    var restored := AudioServer.get_bus_volume_db(music_idx)
    if not _approx(restored, 0.0, 0.5):
        details["duck_did_not_restore"] = restored
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
        "default_bus_layout.tres",
        "autoloads/AudioManager.gd",
    ]
    for rel in required:
        path = os.path.join(PROJECT_DIR, rel)
        assert os.path.isfile(path), f"Required file missing: {path}"


def test_project_godot_registers_audio_manager_autoload():
    content = _read_text(os.path.join(PROJECT_DIR, "project.godot"))
    assert "[autoload]" in content, "project.godot is missing an [autoload] section."
    m = re.search(
        r"^AudioManager\s*=\s*\"\*?res://autoloads/AudioManager\.gd\"",
        content,
        re.MULTILINE,
    )
    assert m is not None, (
        "project.godot does not register AudioManager autoload pointing at "
        "res://autoloads/AudioManager.gd. project.godot:\n" + content
    )


def test_project_godot_references_default_bus_layout():
    content = _read_text(os.path.join(PROJECT_DIR, "project.godot"))
    m = re.search(
        r"audio/buses/default_bus_layout\s*=\s*\"res://default_bus_layout\.tres\"",
        content,
    )
    assert m is not None, (
        "project.godot must contain "
        "audio/buses/default_bus_layout=\"res://default_bus_layout.tres\". "
        "Got project.godot:\n" + content
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


def test_harness_bus_layout(harness_result):
    data, _ = harness_result
    details = data.get("details", {})
    assert "bus_count_too_low" not in details, (
        f"AudioServer.bus_count is too low: {details.get('bus_count_too_low')}"
    )
    assert "bus_names_mismatch" not in details, (
        f"Bus names mismatch: {details.get('bus_names_mismatch')}"
    )
    for key in ("music_send_wrong", "sfx_send_wrong", "voice_send_wrong"):
        assert key not in details, (
            f"Bus send routing wrong: {key} -> {details.get(key)}"
        )


def test_harness_lowpass_effect(harness_result):
    data, _ = harness_result
    details = data.get("details", {})
    assert "music_no_effects" not in details, (
        "Music bus has no effects (expected AudioEffectLowPassFilter at index 0)."
    )
    assert "music_effect_wrong_type" not in details, (
        f"Music bus effect at index 0 is wrong type: "
        f"{details.get('music_effect_wrong_type')}"
    )
    assert "music_lowpass_enabled_by_default" not in details, (
        "AudioEffectLowPassFilter on Music must be disabled by default."
    )


def test_harness_audio_manager_volume(harness_result):
    data, _ = harness_result
    details = data.get("details", {})
    assert "audio_manager_missing" not in details, (
        "AudioManager autoload was not present at /root/AudioManager."
    )
    assert "no_bus_volume_changed_signal" not in details, (
        "AudioManager does not declare a 'bus_volume_changed' signal."
    )
    assert "set_volume_audioserver_mismatch" not in details, (
        "AudioServer.get_bus_volume_db(Music) did not match -6.0 after "
        f"set_bus_volume: {details.get('set_volume_audioserver_mismatch')}"
    )
    assert "signal_not_emitted" not in details, (
        "bus_volume_changed signal was not emitted with ('Music', -6.0). "
        f"Captured signals: {details.get('signal_not_emitted')}"
    )
    assert "get_bus_volume_mismatch" not in details, (
        "get_bus_volume(&\"Music\") did not return -6.0 after set_bus_volume: "
        f"{details.get('get_bus_volume_mismatch')}"
    )


def test_harness_mute(harness_result):
    data, _ = harness_result
    details = data.get("details", {})
    assert "mute_true_failed" not in details, (
        "AudioManager.mute_bus(&\"SFX\", true) did not mute the SFX bus."
    )
    assert "mute_false_failed" not in details, (
        "AudioManager.mute_bus(&\"SFX\", false) did not unmute the SFX bus."
    )


def test_harness_low_pass_toggle(harness_result):
    data, _ = harness_result
    details = data.get("details", {})
    assert "lowpass_enable_failed" not in details, (
        "AudioManager.set_low_pass_enabled(true) did not enable the effect."
    )
    assert "lowpass_disable_failed" not in details, (
        "AudioManager.set_low_pass_enabled(false) did not disable the effect."
    )


def test_harness_duck_music(harness_result):
    data, _ = harness_result
    details = data.get("details", {})
    assert "reset_to_zero_failed" not in details, (
        "Could not reset Music bus volume to 0.0 prior to ducking: "
        f"{details.get('reset_to_zero_failed')}"
    )
    assert "duck_did_not_drop" not in details, (
        "duck_music(-10.0, 0.05) did not drop Music bus volume below -8 dB: "
        f"{details.get('duck_did_not_drop')}"
    )
    assert "duck_did_not_restore" not in details, (
        "Music bus volume did not restore within 0.5 dB of the original after duration: "
        f"{details.get('duck_did_not_restore')}"
    )
