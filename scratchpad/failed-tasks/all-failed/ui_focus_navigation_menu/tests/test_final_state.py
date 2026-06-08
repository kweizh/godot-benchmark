import json
import os
import re
import subprocess

import pytest

PROJECT_DIR = "/home/user/myproject"
PROJECT_GODOT = os.path.join(PROJECT_DIR, "project.godot")
VERIFY_GD = os.path.join(PROJECT_DIR, "verify.gd")
RESULTS_PATH = os.path.join(PROJECT_DIR, "verify_results.json")
KEY_ESCAPE = 4194305  # Godot 4 KEY_ESCAPE constant value

VERIFY_GD_SOURCE = r"""extends SceneTree

const RESULTS_PATH := "res://verify_results.json"
var results: Dictionary = {}
var signal_count: int = 0

func _record(key: String, ok: bool, msg: String = "") -> void:
    results[key] = {"pass": ok, "msg": msg}

func _initialize() -> void:
    _run_all.call_deferred()

func _run_all() -> void:
    await self.process_frame
    _check_input_action()
    _check_autoload_registered()
    _check_main_menu()
    _check_settings_menu()
    await _check_root_toggle()
    await _check_volume_signal()
    _write_results()
    quit(0)

func _write_results() -> void:
    var f := FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
    f.store_string(JSON.stringify({"checks": results}, "  "))
    f.close()

func _walk(node: Node, t: String, out: Array) -> void:
    if node.is_class(t):
        out.append(node)
    for c in node.get_children():
        _walk(c, t, out)

func _walk_named(node: Node, name_: String, out: Array) -> void:
    if String(node.name) == name_:
        out.append(node)
    for c in node.get_children():
        _walk_named(c, name_, out)

func _check_input_action() -> void:
    if not InputMap.has_action("ui_back"):
        _record("input_action_exists", false, "InputMap has no action 'ui_back'")
        _record("input_action_key_escape", false, "no ui_back")
        _record("input_action_joypad", false, "no ui_back")
        return
    _record("input_action_exists", true)
    var events: Array = InputMap.action_get_events("ui_back")
    var has_key := false
    var has_joy := false
    for e in events:
        if e is InputEventKey:
            var k: InputEventKey = e
            if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
                has_key = true
        elif e is InputEventJoypadButton:
            var j: InputEventJoypadButton = e
            if j.button_index == 1:
                has_joy = true
    _record("input_action_key_escape", has_key, "ui_back missing Escape InputEventKey")
    _record("input_action_joypad", has_joy, "ui_back missing InputEventJoypadButton with button_index=1")

func _check_autoload_registered() -> void:
    var cfg := ConfigFile.new()
    var err := cfg.load("res://project.godot")
    if err != OK:
        _record("autoload_registered", false, "Cannot parse project.godot, err=%d" % err)
        _record("autoload_has_volume", false, "no project.godot parse")
        _record("autoload_has_signal", false, "no project.godot parse")
        return
    if not cfg.has_section_key("autoload", "GameSettings"):
        _record("autoload_registered", false, "[autoload] missing GameSettings entry")
        _record("autoload_has_volume", false, "no autoload")
        _record("autoload_has_signal", false, "no autoload")
        return
    var v: String = String(cfg.get_value("autoload", "GameSettings", ""))
    var ok := v.ends_with("res://autoloads/GameSettings.gd")
    _record("autoload_registered", ok, "Expected res://autoloads/GameSettings.gd, got: " + v)
    if not ResourceLoader.exists("res://autoloads/GameSettings.gd"):
        _record("autoload_has_volume", false, "GameSettings.gd file missing")
        _record("autoload_has_signal", false, "GameSettings.gd file missing")
        return
    var scr = load("res://autoloads/GameSettings.gd")
    var inst = scr.new()
    var has_vol := false
    for p in inst.get_property_list():
        if p.name == "volume":
            has_vol = true
            break
    _record("autoload_has_volume", has_vol, "GameSettings has no 'volume' property")
    var has_sig := false
    for s in inst.get_signal_list():
        if s.name == "settings_changed":
            has_sig = true
            break
    _record("autoload_has_signal", has_sig, "GameSettings has no 'settings_changed' signal")
    if inst is Node:
        inst.free()

func _check_main_menu() -> void:
    if not ResourceLoader.exists("res://scenes/MainMenu.tscn"):
        _record("main_menu_buttons", false, "res://scenes/MainMenu.tscn missing")
        _record("main_menu_focus_cycle", false, "scene missing")
        return
    var pk := load("res://scenes/MainMenu.tscn") as PackedScene
    var inst := pk.instantiate()
    var vboxes: Array = []
    _walk(inst, "VBoxContainer", vboxes)
    if vboxes.is_empty():
        _record("main_menu_buttons", false, "No VBoxContainer in MainMenu.tscn")
        _record("main_menu_focus_cycle", false, "no vbox")
        inst.free()
        return
    var vbox: VBoxContainer = vboxes[0]
    var btns: Array = []
    for c in vbox.get_children():
        if c is Button and c.get_class() == "Button":
            btns.append(c)
    var labels: Array = []
    for b in btns:
        labels.append(String((b as Button).text))
    var labels_ok := labels.size() == 3 and labels[0] == "Play" and labels[1] == "Settings" and labels[2] == "Quit"
    _record("main_menu_buttons", labels_ok, "Expected Play/Settings/Quit, got: " + str(labels))
    if not labels_ok:
        _record("main_menu_focus_cycle", false, "buttons incorrect")
        inst.free()
        return
    var play: Button = btns[0]
    var settings_btn: Button = btns[1]
    var quit_btn: Button = btns[2]
    var fbn_play := play.get_node_or_null(play.focus_neighbor_bottom)
    var fbn_settings := settings_btn.get_node_or_null(settings_btn.focus_neighbor_bottom)
    var fbn_quit := quit_btn.get_node_or_null(quit_btn.focus_neighbor_bottom)
    var ftn_play := play.get_node_or_null(play.focus_neighbor_top)
    var ftn_settings := settings_btn.get_node_or_null(settings_btn.focus_neighbor_top)
    var ftn_quit := quit_btn.get_node_or_null(quit_btn.focus_neighbor_top)
    var cycle_ok := fbn_play == settings_btn and fbn_settings == quit_btn and fbn_quit == play \
                 and ftn_play == quit_btn and ftn_settings == play and ftn_quit == settings_btn
    _record("main_menu_focus_cycle", cycle_ok,
        "focus_neighbor cycle invalid. bottoms=[%s,%s,%s] tops=[%s,%s,%s]" %
        [str(fbn_play), str(fbn_settings), str(fbn_quit), str(ftn_play), str(ftn_settings), str(ftn_quit)])
    inst.free()

func _check_settings_menu() -> void:
    if not ResourceLoader.exists("res://scenes/SettingsMenu.tscn"):
        _record("settings_has_slider", false, "res://scenes/SettingsMenu.tscn missing")
        _record("settings_has_option_3", false, "scene missing")
        _record("settings_has_checkbox", false, "scene missing")
        _record("settings_has_back_button", false, "scene missing")
        return
    var pk := load("res://scenes/SettingsMenu.tscn") as PackedScene
    var inst := pk.instantiate()
    var sliders: Array = []
    var options: Array = []
    var checks_arr: Array = []
    var buttons_arr: Array = []
    _walk(inst, "HSlider", sliders)
    _walk(inst, "OptionButton", options)
    _walk(inst, "CheckBox", checks_arr)
    _walk(inst, "Button", buttons_arr)
    _record("settings_has_slider", sliders.size() >= 1, "no HSlider in SettingsMenu")
    var opt_ok := false
    if options.size() >= 1:
        opt_ok = (options[0] as OptionButton).item_count == 3
    _record("settings_has_option_3", opt_ok, "OptionButton must exist and have item_count == 3")
    _record("settings_has_checkbox", checks_arr.size() >= 1, "no CheckBox in SettingsMenu")
    var back_present := false
    for b in buttons_arr:
        if b.get_class() == "Button" and String((b as Button).text) == "Back":
            back_present = true
            break
    _record("settings_has_back_button", back_present, "no plain Button with text 'Back'")
    inst.free()

func _check_root_toggle() -> void:
    if not ResourceLoader.exists("res://scenes/RootUI.tscn"):
        _record("root_initial_visibility", false, "res://scenes/RootUI.tscn missing")
        _record("root_ui_back_toggles", false, "scene missing")
        return
    var pk := load("res://scenes/RootUI.tscn") as PackedScene
    var inst := pk.instantiate()
    get_root().add_child(inst)
    await self.process_frame
    await self.process_frame
    var mm_list: Array = []
    var sm_list: Array = []
    _walk_named(inst, "MainMenu", mm_list)
    _walk_named(inst, "SettingsMenu", sm_list)
    if mm_list.is_empty() or sm_list.is_empty():
        _record("root_initial_visibility", false, "RootUI must contain children named MainMenu and SettingsMenu")
        _record("root_ui_back_toggles", false, "menus missing in RootUI")
        get_root().remove_child(inst)
        inst.free()
        return
    var mm: CanvasItem = mm_list[0]
    var sm: CanvasItem = sm_list[0]
    _record("root_initial_visibility", mm.visible and not sm.visible,
        "Expected MainMenu visible, SettingsMenu hidden. mm=%s sm=%s" % [str(mm.visible), str(sm.visible)])
    sm.visible = true
    mm.visible = false
    await self.process_frame
    Input.action_press("ui_back")
    await self.process_frame
    await self.process_frame
    Input.action_release("ui_back")
    await self.process_frame
    _record("root_ui_back_toggles", (not sm.visible) and mm.visible,
        "After ui_back: expected SettingsMenu hidden, MainMenu visible. mm=%s sm=%s" % [str(mm.visible), str(sm.visible)])
    get_root().remove_child(inst)
    inst.free()

func _on_settings_changed_handler(_a = null, _b = null, _c = null) -> void:
    signal_count += 1

func _check_volume_signal() -> void:
    if not ResourceLoader.exists("res://autoloads/GameSettings.gd"):
        _record("volume_signal", false, "GameSettings.gd missing")
        return
    if not ResourceLoader.exists("res://scenes/SettingsMenu.tscn"):
        _record("volume_signal", false, "SettingsMenu.tscn missing")
        return
    var gs: Node = get_root().get_node_or_null("GameSettings")
    var added_manual := false
    if gs == null:
        var scr = load("res://autoloads/GameSettings.gd")
        var node = scr.new()
        if node is Node:
            node.name = "GameSettings"
            get_root().add_child(node)
            gs = node
            added_manual = true
        else:
            _record("volume_signal", false, "GameSettings.gd does not extend Node")
            return
    signal_count = 0
    if not gs.is_connected("settings_changed", Callable(self, "_on_settings_changed_handler")):
        gs.connect("settings_changed", Callable(self, "_on_settings_changed_handler"))
    var pk := load("res://scenes/SettingsMenu.tscn") as PackedScene
    var inst := pk.instantiate()
    get_root().add_child(inst)
    await self.process_frame
    await self.process_frame
    var sliders: Array = []
    _walk(inst, "HSlider", sliders)
    if sliders.is_empty():
        _record("volume_signal", false, "no HSlider in SettingsMenu instance")
        get_root().remove_child(inst)
        inst.free()
        if added_manual:
            gs.queue_free()
        return
    var slider: HSlider = sliders[0]
    slider.value = 0.42
    await self.process_frame
    await self.process_frame
    var vol_val = gs.get("volume")
    var num_ok := typeof(vol_val) in [TYPE_FLOAT, TYPE_INT] and abs(float(vol_val) - 0.42) < 1e-4
    var ok := num_ok and signal_count >= 1
    _record("volume_signal", ok, "Expect volume==0.42 and signal emitted. got volume=%s signals=%d" % [str(vol_val), signal_count])
    get_root().remove_child(inst)
    inst.free()
    if added_manual:
        gs.queue_free()
"""


def _write_verify_script():
    with open(VERIFY_GD, "w") as f:
        f.write(VERIFY_GD_SOURCE)


@pytest.fixture(scope="module")
def godot_run():
    if os.path.exists(RESULTS_PATH):
        os.remove(RESULTS_PATH)
    _write_verify_script()
    proc = subprocess.run(
        ["godot", "--headless", "--path", PROJECT_DIR, "--script", "res://verify.gd"],
        capture_output=True,
        text=True,
        timeout=240,
    )
    data = None
    if os.path.exists(RESULTS_PATH):
        with open(RESULTS_PATH) as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                data = None
    return proc, data


def test_scene_files_exist():
    for p in [
        "scenes/MainMenu.tscn",
        "scenes/SettingsMenu.tscn",
        "scenes/RootUI.tscn",
        "autoloads/GameSettings.gd",
    ]:
        full = os.path.join(PROJECT_DIR, p)
        assert os.path.isfile(full), f"Expected file {full} to exist."


def test_project_godot_has_ui_back_with_escape_and_joypad():
    with open(PROJECT_GODOT) as f:
        content = f.read()
    m = re.search(r"^ui_back\s*=\s*\{.*?^\}", content, re.MULTILINE | re.DOTALL)
    assert m, "project.godot does not contain a 'ui_back' input action block."
    block = m.group(0)
    assert "InputEventKey" in block, "ui_back has no InputEventKey event"
    assert (
        f'"keycode":{KEY_ESCAPE}' in block
        or f'"physical_keycode":{KEY_ESCAPE}' in block
        or f"keycode: {KEY_ESCAPE}" in block
    ), f"ui_back must include an Escape key event (keycode {KEY_ESCAPE})."
    assert "InputEventJoypadButton" in block, "ui_back has no InputEventJoypadButton event"
    assert re.search(r'"button_index"\s*:\s*1\b', block) or re.search(
        r"button_index\s*=\s*1\b", block
    ), "ui_back joypad event must have button_index == 1"


def test_project_godot_registers_game_settings_autoload():
    with open(PROJECT_GODOT) as f:
        content = f.read()
    pattern = re.compile(
        r"^\[autoload\][^\[]*?^GameSettings\s*=\s*\"\*?res://autoloads/GameSettings\.gd\"",
        re.MULTILINE | re.DOTALL,
    )
    assert pattern.search(content), (
        "project.godot must register GameSettings autoload pointing to "
        "res://autoloads/GameSettings.gd in the [autoload] section."
    )


def test_godot_verify_script_runs(godot_run):
    proc, data = godot_run
    assert proc.returncode == 0, (
        f"verify.gd run failed (rc={proc.returncode}).\n"
        f"stdout=\n{proc.stdout}\nstderr=\n{proc.stderr}"
    )
    assert data is not None, (
        f"verify_results.json missing or unreadable.\nstdout=\n{proc.stdout}\nstderr=\n{proc.stderr}"
    )
    assert "checks" in data and isinstance(data["checks"], dict), (
        f"verify_results.json missing 'checks' map. got: {data}"
    )


def _check(godot_run, name):
    _, data = godot_run
    assert data is not None, "verify_results.json missing; see verify run output"
    checks = data.get("checks", {})
    assert name in checks, f"verify.gd did not emit check '{name}'. Got: {sorted(checks.keys())}"
    info = checks[name]
    assert info.get("pass") is True, f"Check '{name}' failed: {info.get('msg')}"


def test_input_action_exists(godot_run):
    _check(godot_run, "input_action_exists")


def test_input_action_key_escape(godot_run):
    _check(godot_run, "input_action_key_escape")


def test_input_action_joypad(godot_run):
    _check(godot_run, "input_action_joypad")


def test_autoload_registered(godot_run):
    _check(godot_run, "autoload_registered")


def test_autoload_has_volume(godot_run):
    _check(godot_run, "autoload_has_volume")


def test_autoload_has_signal(godot_run):
    _check(godot_run, "autoload_has_signal")


def test_main_menu_buttons(godot_run):
    _check(godot_run, "main_menu_buttons")


def test_main_menu_focus_cycle(godot_run):
    _check(godot_run, "main_menu_focus_cycle")


def test_settings_has_slider(godot_run):
    _check(godot_run, "settings_has_slider")


def test_settings_has_option_3(godot_run):
    _check(godot_run, "settings_has_option_3")


def test_settings_has_checkbox(godot_run):
    _check(godot_run, "settings_has_checkbox")


def test_settings_has_back_button(godot_run):
    _check(godot_run, "settings_has_back_button")


def test_root_initial_visibility(godot_run):
    _check(godot_run, "root_initial_visibility")


def test_root_ui_back_toggles(godot_run):
    _check(godot_run, "root_ui_back_toggles")


def test_volume_signal(godot_run):
    _check(godot_run, "volume_signal")
