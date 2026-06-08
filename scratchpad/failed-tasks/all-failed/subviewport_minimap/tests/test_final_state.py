import os
import shutil
import subprocess
import textwrap

import pytest

PROJECT_DIR = "/home/user/myproject"
HARNESS_SCRIPT = os.path.join(PROJECT_DIR, "harbor_test_harness.gd")

HARNESS_SOURCE = textwrap.dedent(
    '''
    extends SceneTree

    func _emit(line: String) -> void:
        print(line)

    func _fail(name: String, reason: String) -> void:
        _emit("FAIL %s :: %s" % [name, reason])

    func _pass(name: String) -> void:
        _emit("PASS %s" % name)

    func _find_descendant_of_type(root: Node, type_name: String) -> Node:
        if root == null:
            return null
        if root.is_class(type_name):
            return root
        for c in root.get_children():
            var r = _find_descendant_of_type(c, type_name)
            if r != null:
                return r
        return null

    func _approx(a: Vector2, b: Vector2, tol: float) -> bool:
        return absf(a.x - b.x) <= tol and absf(a.y - b.y) <= tol

    func _initialize() -> void:
        _emit("HARNESS_START")
        _run_checks()
        _emit("HARNESS_DONE")
        quit()

    func _run_checks() -> void:
        # 1. Load Minimap.tscn and inspect structure
        var minimap_packed: PackedScene = load("res://scenes/Minimap.tscn")
        if minimap_packed == null:
            _fail("load_minimap_scene", "Failed to load res://scenes/Minimap.tscn")
            return
        _pass("load_minimap_scene")

        var minimap_instance: Node = minimap_packed.instantiate()
        if minimap_instance == null:
            _fail("instantiate_minimap_scene", "Could not instantiate Minimap")
            return
        _pass("instantiate_minimap_scene")

        if not minimap_instance.is_class("SubViewportContainer"):
            _fail("minimap_root_is_subviewport_container", "Root class is %s" % minimap_instance.get_class())
            return
        _pass("minimap_root_is_subviewport_container")

        var subviewport: SubViewport = null
        for c in minimap_instance.get_children():
            if c is SubViewport:
                subviewport = c
                break
        if subviewport == null:
            _fail("minimap_has_subviewport_child", "No SubViewport child under SubViewportContainer")
            return
        _pass("minimap_has_subviewport_child")

        if subviewport.size != Vector2i(256, 256):
            _fail("subviewport_size", "Expected Vector2i(256, 256), got %s" % str(subviewport.size))
            return
        _pass("subviewport_size")

        if not subviewport.transparent_bg:
            _fail("subviewport_transparent_bg", "transparent_bg should be true")
            return
        _pass("subviewport_transparent_bg")

        var mini_camera: Camera2D = _find_descendant_of_type(subviewport, "Camera2D")
        if mini_camera == null:
            _fail("minimap_camera_exists", "No Camera2D under SubViewport")
            return
        _pass("minimap_camera_exists")

        if not _approx(mini_camera.zoom, Vector2(0.1, 0.1), 0.0001):
            _fail("minimap_camera_zoom", "Expected zoom (0.1, 0.1), got %s" % str(mini_camera.zoom))
            return
        _pass("minimap_camera_zoom")

        # 2. Load World.tscn and verify structure
        var world_packed: PackedScene = load("res://scenes/World.tscn")
        if world_packed == null:
            _fail("load_world_scene", "Failed to load res://scenes/World.tscn")
            return
        _pass("load_world_scene")

        var world_instance: Node = world_packed.instantiate()
        if world_instance == null:
            _fail("instantiate_world_scene", "Could not instantiate World")
            return
        _pass("instantiate_world_scene")

        if world_instance.name != "World":
            _fail("world_root_name", "Expected root name 'World', got '%s'" % world_instance.name)
            return
        _pass("world_root_name")

        var player_node: Node = _find_descendant_of_type(world_instance, "CharacterBody2D")
        if player_node == null:
            _fail("player_exists", "No CharacterBody2D found in World")
            return
        _pass("player_exists")

        if player_node.name != "Player":
            _fail("player_name", "Expected CharacterBody2D named 'Player', got '%s'" % player_node.name)
            return
        _pass("player_name")

        # 3. Add World to the tree so groups become populated, then check group
        get_root().add_child(world_instance)
        await process_frame
        var pois: Array = get_nodes_in_group("poi")
        if pois.size() < 3:
            _fail("poi_group_count", "Expected at least 3 nodes in group 'poi', got %d" % pois.size())
            return
        _pass("poi_group_count")

        # 4. Add minimap, wire it up and verify POI markers created + signal count
        get_root().add_child(minimap_instance)
        # Make sure the minimap camera is not current in the main viewport
        if mini_camera.is_current():
            # Allowable, but spec says it should be current in its own viewport only.
            # We do a softer check: enabled inside subviewport
            pass

        # Set NodePaths if the script supports it
        if "world_root" in minimap_instance:
            minimap_instance.world_root = minimap_instance.get_path_to(world_instance)
        if "player_path" in minimap_instance:
            minimap_instance.player_path = minimap_instance.get_path_to(player_node)

        # Connect signal to a counter
        var signal_count: int = 0
        var counter_ref := {"count": 0}
        if minimap_instance.has_signal("poi_added"):
            minimap_instance.connect("poi_added", func(_idx): counter_ref.count += 1)
        else:
            _fail("poi_added_signal_defined", "Minimap script must declare signal poi_added(poi_index: int)")
            return
        _pass("poi_added_signal_defined")

        # Re-invoke ready logic by removing and re-adding (so signal handler is attached before markers are created)
        # However minimap was just added: _ready already fired. We need to call a method or reset.
        # To make this deterministic, remove and re-add minimap after signal connection.
        get_root().remove_child(minimap_instance)
        counter_ref.count = 0
        if minimap_instance.has_signal("poi_added"):
            # disconnect any old, reconnect
            for c in minimap_instance.poi_added.get_connections():
                minimap_instance.poi_added.disconnect(c.callable)
            minimap_instance.connect("poi_added", func(_idx): counter_ref.count += 1)
        # Reset exports just in case
        if "world_root" in minimap_instance:
            minimap_instance.world_root = NodePath()  # will be reassigned below
        get_root().add_child(minimap_instance)
        if "world_root" in minimap_instance:
            minimap_instance.world_root = minimap_instance.get_path_to(world_instance)
        if "player_path" in minimap_instance:
            minimap_instance.player_path = minimap_instance.get_path_to(player_node)

        # Allow scripts that read NodePaths in _ready by calling a re-init if available, otherwise rely on _process
        if minimap_instance.has_method("rebuild_markers"):
            minimap_instance.rebuild_markers()

        await process_frame
        await process_frame

        if counter_ref.count != pois.size():
            _fail("poi_added_emit_count", "Expected poi_added emitted %d times, got %d" % [pois.size(), counter_ref.count])
            return
        _pass("poi_added_emit_count")

        # Verify get_marker_for_poi returns matching node
        if not minimap_instance.has_method("get_marker_for_poi"):
            _fail("get_marker_for_poi_method", "Method get_marker_for_poi missing")
            return
        var marker0 = minimap_instance.get_marker_for_poi(0)
        if marker0 == null:
            _fail("get_marker_for_poi_nonnull", "get_marker_for_poi(0) returned null")
            return
        if not (marker0 is Node2D):
            _fail("get_marker_for_poi_type", "Marker is not Node2D, got %s" % marker0.get_class())
            return
        var poi0: Node2D = pois[0]
        if not _approx(marker0.position, poi0.global_position, 0.01):
            _fail("get_marker_for_poi_position", "Marker pos %s != POI pos %s" % [str(marker0.position), str(poi0.global_position)])
            return
        _pass("get_marker_for_poi_position")

        # Move player and check marker after one frame
        player_node.global_position = Vector2(123, -45)
        await process_frame
        await process_frame

        # Find player marker via either method or by name convention
        var player_marker: Node2D = null
        if minimap_instance.has_method("get_player_marker"):
            player_marker = minimap_instance.get_player_marker()
        else:
            # Try finding "player_marker" or "PlayerMarker" or fallback to any direct Node2D child that's not a POI marker
            for c in minimap_instance.get_children():
                if c.name.to_lower().findn("player") != -1 and c is Node2D:
                    player_marker = c
                    break
            if player_marker == null:
                # Scan SubViewport descendants
                player_marker = _find_node_by_name_recursive(minimap_instance, "PlayerMarker")
                if player_marker == null:
                    player_marker = _find_node_by_name_recursive(minimap_instance, "player_marker")
        if player_marker == null:
            _fail("player_marker_found", "Could not locate player marker node")
            return
        if not _approx(player_marker.position, Vector2(123, -45), 0.01):
            _fail("player_marker_tracks_player", "Marker pos %s != player pos (123, -45)" % str(player_marker.position))
            return
        _pass("player_marker_tracks_player")

        _emit("ALL_CHECKS_PASSED")

    func _find_node_by_name_recursive(root: Node, name: String) -> Node:
        if root == null:
            return null
        if root.name == name:
            return root
        for c in root.get_children():
            var r = _find_node_by_name_recursive(c, name)
            if r != null:
                return r
        return null
    '''
).strip()

REQUIRED_PASSES = [
    "load_minimap_scene",
    "instantiate_minimap_scene",
    "minimap_root_is_subviewport_container",
    "minimap_has_subviewport_child",
    "subviewport_size",
    "subviewport_transparent_bg",
    "minimap_camera_exists",
    "minimap_camera_zoom",
    "load_world_scene",
    "instantiate_world_scene",
    "world_root_name",
    "player_exists",
    "player_name",
    "poi_group_count",
    "poi_added_signal_defined",
    "poi_added_emit_count",
    "get_marker_for_poi_position",
    "player_marker_tracks_player",
]


@pytest.fixture(scope="session")
def harness_output():
    assert shutil.which("godot") is not None, "godot binary not found in PATH."
    assert os.path.isdir(PROJECT_DIR), f"Project dir {PROJECT_DIR} missing."
    with open(HARNESS_SCRIPT, "w") as f:
        f.write(HARNESS_SOURCE)
    try:
        result = subprocess.run(
            [
                "godot",
                "--headless",
                "--path",
                PROJECT_DIR,
                "--script",
                "res://harbor_test_harness.gd",
            ],
            capture_output=True,
            text=True,
            timeout=180,
        )
    finally:
        if os.path.isfile(HARNESS_SCRIPT):
            os.remove(HARNESS_SCRIPT)
    combined = result.stdout + "\n" + result.stderr
    return combined, result.returncode


def test_required_project_files_exist():
    for rel in ("scenes/Minimap.tscn", "scenes/World.tscn", "scripts/Minimap.gd"):
        path = os.path.join(PROJECT_DIR, rel)
        assert os.path.isfile(path), f"Required project file missing: {path}"


def test_harness_runs_without_fatal_errors(harness_output):
    combined, _rc = harness_output
    assert "HARNESS_START" in combined, (
        f"Harness did not start. Output:\n{combined}"
    )
    assert "HARNESS_DONE" in combined, (
        f"Harness did not complete. Output:\n{combined}"
    )


@pytest.mark.parametrize("check_name", REQUIRED_PASSES)
def test_harness_pass(check_name, harness_output):
    combined, _rc = harness_output
    fail_marker = f"FAIL {check_name} ::"
    pass_marker = f"PASS {check_name}"
    assert fail_marker not in combined, (
        f"Check '{check_name}' failed. Harness output:\n{combined}"
    )
    assert pass_marker in combined, (
        f"Check '{check_name}' did not pass. Harness output:\n{combined}"
    )


def test_all_checks_passed_marker(harness_output):
    combined, _rc = harness_output
    assert "ALL_CHECKS_PASSED" in combined, (
        f"Final summary marker missing. Output:\n{combined}"
    )
