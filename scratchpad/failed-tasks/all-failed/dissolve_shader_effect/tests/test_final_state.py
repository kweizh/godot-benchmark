import os
import re
import json
import pytest
import shutil
from xprocess import ProcessStarter

PROJECT_DIR = "/home/user/godot-benchmark"
TEST_RUNNER_PATH = os.path.join(PROJECT_DIR, "test_runner.gd")
TEST_RESULT_PATH = os.path.join(PROJECT_DIR, "test_result.json")

def test_shader_file_exists():
    shader_path = os.path.join(PROJECT_DIR, "dissolve.gdshader")
    assert os.path.isfile(shader_path), f"Shader file {shader_path} does not exist."
    
    with open(shader_path, "r") as f:
        content = f.read()
        
    # Check for canvas_item shader type
    assert "shader_type canvas_item;" in content, "Shader type must be canvas_item."
    
    # Check for uniforms
    assert re.search(r"uniform\s+float\s+dissolve_amount", content) is not None, \
        "Shader must have a float uniform 'dissolve_amount'."
    assert re.search(r"uniform\s+sampler2D\s+dissolve_texture", content) is not None, \
        "Shader must have a sampler2D uniform 'dissolve_texture'."

def test_script_file_exists():
    script_path = os.path.join(PROJECT_DIR, "dissolving_sprite.gd")
    assert os.path.isfile(script_path), f"Script file {script_path} does not exist."
    
    with open(script_path, "r") as f:
        content = f.read()
        
    # Check that it extends Sprite2D
    assert "extends Sprite2D" in content, "Script must extend Sprite2D."
    
    # Check for custom signal
    assert re.search(r"signal\s+dissolve_completed", content) is not None, \
        "Script must define a custom signal 'dissolve_completed'."
        
    # Check for custom method
    assert re.search(r"func\s+dissolve\s*\(\s*\)", content) is not None, \
        "Script must implement a custom method 'dissolve()'."

@pytest.fixture
def write_test_runner():
    # Write test_runner.gd
    test_runner_code = """extends SceneTree

func _init():
    run_tests.call_deferred()

func run_tests():
    var success = await _run_tests_impl()
    write_result(success)
    quit(0)

func _run_tests_impl() -> bool:
    var script = load("res://dissolving_sprite.gd")
    if not script:
        print("Error: Could not load dissolving_sprite.gd")
        return false
        
    var sprite = Sprite2D.new()
    sprite.set_script(script)
    
    var shader = load("res://dissolve.gdshader")
    if not shader:
        print("Error: Could not load dissolve.gdshader")
        return false
        
    var material = ShaderMaterial.new()
    material.shader = shader
    sprite.material = material
    
    # Check shader parameters
    material.set_shader_parameter("dissolve_amount", 0.0)
    
    var noise = FastNoiseLite.new()
    var noise_tex = NoiseTexture2D.new()
    noise_tex.noise = noise
    material.set_shader_parameter("dissolve_texture", noise_tex)
    
    if not sprite.has_method("dissolve"):
        print("Error: Sprite2D does not have 'dissolve' method")
        return false
        
    var signal_emitted = false
    sprite.dissolve_completed.connect(func():
        signal_emitted = true
    )
    
    root.add_child(sprite)
    
    sprite.dissolve()
    
    var initial_amount = material.get_shader_parameter("dissolve_amount")
    if initial_amount > 0.01:
        print("Error: Initial dissolve_amount should be close to 0.0, got ", initial_amount)
        return false
        
    await create_timer(1.2).timeout
    
    var final_amount = material.get_shader_parameter("dissolve_amount")
    if abs(final_amount - 1.0) > 0.01:
        print("Error: Final dissolve_amount should be close to 1.0, got ", final_amount)
        return false
        
    if not signal_emitted:
        print("Error: dissolve_completed signal was not emitted")
        return false
        
    print("All tests passed inside Godot!")
    return true

func write_result(success: bool):
    var file = FileAccess.open("res://test_result.json", FileAccess.WRITE)
    if file:
        var dict = {"status": "pass" if success else "fail"}
        file.store_string(JSON.stringify(dict))
        file.close()
"""
    with open(TEST_RUNNER_PATH, "w") as f:
        f.write(test_runner_code)
        
    # Clean up previous test results if any
    if os.path.exists(TEST_RESULT_PATH):
        os.remove(TEST_RESULT_PATH)
        
    yield
    
    # Teardown: clean up test files
    if os.path.exists(TEST_RUNNER_PATH):
        os.remove(TEST_RUNNER_PATH)
    if os.path.exists(TEST_RESULT_PATH):
        os.remove(TEST_RESULT_PATH)

def test_godot_headless_execution(write_test_runner, xprocess):
    # Ensure godot is in path
    assert shutil.which("godot") is not None, "godot binary not found in PATH."
    
    class GodotStarter(ProcessStarter):
        name = "godot_test_runner"
        args = ["godot", "--headless", "--script", "test_runner.gd"]
        env = os.environ.copy()  # set as class attribute!
        popen_kwargs = {
            "cwd": PROJECT_DIR,
            "text": True,
        }
        
        def startup_check(self):
            # The process is complete when test_result.json is written
            return os.path.exists(TEST_RESULT_PATH)
            
    # Run godot via xprocess
    xprocess.ensure(GodotStarter.name, GodotStarter)
    
    # Read result
    assert os.path.exists(TEST_RESULT_PATH), "Godot execution did not produce a test result file."
    with open(TEST_RESULT_PATH, "r") as f:
        result = json.load(f)
        
    assert result.get("status") == "pass", "Godot internal tests failed."
    
    # Clean up xprocess info
    info = xprocess.getinfo(GodotStarter.name)
    info.terminate()
