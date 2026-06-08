import os
import shutil

PROJECT_DIR = "/home/user/godot-benchmark"

def test_godot_binary_available():
    # Godot binary should be in PATH
    assert shutil.which("godot") is not None, "godot binary not found in PATH."

def test_project_dir_exists():
    # The project directory must exist
    assert os.path.isdir(PROJECT_DIR), f"Project directory {PROJECT_DIR} does not exist."

def test_project_godot_exists():
    # The project.godot file must exist initially
    project_godot_path = os.path.join(PROJECT_DIR, "project.godot")
    assert os.path.isfile(project_godot_path), f"project.godot file {project_godot_path} does not exist."

def test_initial_files_dont_exist():
    # The files to be created should not exist yet
    shader_path = os.path.join(PROJECT_DIR, "dissolve.gdshader")
    script_path = os.path.join(PROJECT_DIR, "dissolving_sprite.gd")
    
    assert not os.path.exists(shader_path), f"Shader file {shader_path} already exists."
    assert not os.path.exists(script_path), f"Script file {script_path} already exists."
