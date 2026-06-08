import os
import json
import pytest
import math
from xprocess import ProcessStarter

PROJECT_DIR = "/home/user/godot-project"
LOG_FILE = os.path.join(PROJECT_DIR, "path_log.json")

@pytest.fixture(scope="session")
def run_godot_simulation(xprocess):
    """
    Starts the Godot headless simulation using pytest-xprocess.
    The simulation runs until the log file is generated.
    """
    # Clean up any pre-existing log file
    if os.path.exists(LOG_FILE):
        try:
            os.remove(LOG_FILE)
        except OSError as e:
            pytest.fail(f"Failed to remove pre-existing log file {LOG_FILE}: {e}")

    class GodotStarter(ProcessStarter):
        name = "godot_simulation"
        args = ["godot", "--headless", "--path", PROJECT_DIR]
        env = os.environ.copy()
        popen_kwargs = {
            "cwd": PROJECT_DIR,
            "text": True,
        }
        timeout = 30  # Maximum time to wait for the simulation to complete

        def startup_check(self):
            # The simulation is complete when the path log file is created
            return os.path.exists(LOG_FILE)

    # Start the process and wait for startup_check to return True
    xprocess.ensure(GodotStarter.name, GodotStarter)

    yield

    # Teardown: cleanly terminate the process
    try:
        info = xprocess.getinfo(GodotStarter.name)
        info.terminate()
    except Exception:
        pass


def test_godot_project_exists():
    """Verify that the Godot project directory and project.godot file exist."""
    assert os.path.isdir(PROJECT_DIR), f"Godot project directory not found at {PROJECT_DIR}"
    project_godot = os.path.join(PROJECT_DIR, "project.godot")
    assert os.path.isfile(project_godot), f"project.godot file not found at {project_godot}"


def test_simulation_log_generated(run_godot_simulation):
    """Verify that the simulation ran and successfully generated the log file."""
    assert os.path.isfile(LOG_FILE), f"Simulation log file was not generated at {LOG_FILE}"


def test_velocity_computed_triggered(run_godot_simulation):
    """Verify that the NavigationAgent2D's velocity_computed signal was triggered."""
    with open(LOG_FILE, "r") as f:
        data = json.load(f)
    
    assert "velocity_computed_triggered" in data, "Key 'velocity_computed_triggered' is missing from the log file."
    assert data["velocity_computed_triggered"] is True, "The 'velocity_computed' signal callback was not triggered during the simulation."


def test_agent_path_validity(run_godot_simulation):
    """Verify that the agent's logged path has valid coordinates and starts/ends correctly."""
    with open(LOG_FILE, "r") as f:
        data = json.load(f)
    
    assert "path" in data, "Key 'path' is missing from the log file."
    path = data["path"]
    assert isinstance(path, list), "Expected 'path' to be a list of coordinates."
    assert len(path) >= 10, f"Expected at least 10 logged path coordinates, but got {len(path)}."

    # Verify start position: close to (50, 250)
    start_pos = path[0]
    assert len(start_pos) == 2, f"Expected 2D coordinate pair, got {start_pos}"
    start_dist = math.sqrt((start_pos[0] - 50) ** 2 + (start_pos[1] - 250) ** 2)
    assert start_dist < 15.0, f"Agent started too far from (50, 250): {start_pos} (distance: {start_dist:.2f}px)"

    # Verify end position: close to (450, 250)
    end_pos = path[-1]
    assert len(end_pos) == 2, f"Expected 2D coordinate pair, got {end_pos}"
    end_dist = math.sqrt((end_pos[0] - 450) ** 2 + (end_pos[1] - 250) ** 2)
    assert end_dist < 20.0, f"Agent failed to reach target (450, 250): {end_pos} (distance: {end_dist:.2f}px)"


def test_obstacle_avoidance(run_godot_simulation):
    """Verify that the agent successfully avoided the obstacle at (250, 250) during movement."""
    with open(LOG_FILE, "r") as f:
        data = json.load(f)
    
    path = data["path"]
    obstacle_pos = (250, 250)
    min_allowed_distance = 35.0  # Obstacle radius is 40.0, we allow a small margin of error (35.0px)
    
    # 1. Verify that the agent never collided with/passed through the obstacle
    for i, pos in enumerate(path):
        dist = math.sqrt((pos[0] - obstacle_pos[0]) ** 2 + (pos[1] - obstacle_pos[1]) ** 2)
        assert dist >= min_allowed_distance, (
            f"Agent collided with obstacle at index {i}: position {pos} is too close to "
            f"obstacle {obstacle_pos} (distance: {dist:.2f}px, minimum allowed: {min_allowed_distance}px)"
        )

    # 2. Verify that the agent actually deviated from the straight line y = 250 to avoid the obstacle
    deviated = False
    for pos in path:
        x, y = pos[0], pos[1]
        if 200.0 <= x <= 300.0:
            y_deviation = abs(y - 250.0)
            if y_deviation >= 30.0:
                deviated = True
                break
                
    assert deviated, (
        "Agent did not dynamically avoid the obstacle. The path did not show a deviation of at least "
        "30px from the y=250 horizontal line when passing near the obstacle (x between 200 and 300)."
    )
