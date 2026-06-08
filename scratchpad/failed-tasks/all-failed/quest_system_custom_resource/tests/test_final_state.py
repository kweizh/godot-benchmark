import json
import os
import re
import shutil
import subprocess

import pytest

PROJECT_DIR = "/home/user/quest_project"
VERIFY_SUBDIR = os.path.join(PROJECT_DIR, "__verify__")
HARNESS_SRC_DIR = os.path.join(os.path.dirname(__file__), "harness")
GODOT_TIMEOUT_SECONDS = 180


def _read_project_godot() -> str:
    path = os.path.join(PROJECT_DIR, "project.godot")
    assert os.path.isfile(path), f"project.godot not found at {path}"
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


@pytest.fixture(scope="module")
def harness_results():
    """Inject the test harness into the project, run Godot headlessly,
    parse RESULT lines and return them as a dict of name->record."""
    assert os.path.isdir(PROJECT_DIR), f"Project dir {PROJECT_DIR} not found"
    # Clean any previous verify artifacts.
    if os.path.isdir(VERIFY_SUBDIR):
        shutil.rmtree(VERIFY_SUBDIR)
    os.makedirs(VERIFY_SUBDIR, exist_ok=True)
    # Copy harness files into res://__verify__/
    for name in ("run.gd", "run.tscn"):
        src = os.path.join(HARNESS_SRC_DIR, name)
        dst = os.path.join(VERIFY_SUBDIR, name)
        shutil.copyfile(src, dst)

    # Run Godot headlessly with the harness scene.
    cmd = [
        "godot",
        "--headless",
        "--path",
        PROJECT_DIR,
        "res://__verify__/run.tscn",
    ]
    env = os.environ.copy()
    # Force importing of new assets in case the project hasn't been opened yet.
    completed = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=GODOT_TIMEOUT_SECONDS,
        env=env,
    )
    combined = completed.stdout + "\n" + completed.stderr

    results: dict[str, dict] = {}
    saw_done = False
    for line in combined.splitlines():
        line = line.strip()
        if line.startswith("RESULT:"):
            payload = line[len("RESULT:"):].strip()
            try:
                rec = json.loads(payload)
            except json.JSONDecodeError:
                continue
            name = rec.get("name")
            if isinstance(name, str):
                results[name] = rec
        elif line == "RESULT_DONE":
            saw_done = True

    yield {
        "results": results,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
        "returncode": completed.returncode,
        "saw_done": saw_done,
    }

    # Clean up.
    if os.path.isdir(VERIFY_SUBDIR):
        shutil.rmtree(VERIFY_SUBDIR, ignore_errors=True)


def _require(harness_results, name: str):
    rec = harness_results["results"].get(name)
    assert rec is not None, (
        f"Harness produced no RESULT named {name!r}. "
        f"Available: {sorted(harness_results['results'].keys())}\n"
        f"stdout=\n{harness_results['stdout']}\n"
        f"stderr=\n{harness_results['stderr']}"
    )
    assert rec.get("ok") is True, (
        f"Harness assertion {name!r} failed: {rec.get('detail')!r}"
    )


def test_harness_completed(harness_results):
    assert harness_results["saw_done"], (
        "Harness did not reach completion. stdout=\n"
        f"{harness_results['stdout']}\nstderr=\n{harness_results['stderr']}"
    )


def test_project_godot_declares_autoload():
    content = _read_project_godot()
    # The autoload section must contain a QuestManager entry pointing to the
    # expected script path.
    assert re.search(r"^\s*\[autoload\]", content, re.MULTILINE), (
        "project.godot is missing an [autoload] section."
    )
    assert re.search(
        r"^\s*QuestManager\s*=\s*\"\*?res://autoloads/QuestManager\.gd\"",
        content,
        re.MULTILINE,
    ), "project.godot must autoload QuestManager from res://autoloads/QuestManager.gd"


def test_quest_files_exist():
    for rel in (
        "scripts/QuestObjective.gd",
        "scripts/Quest.gd",
        "autoloads/QuestManager.gd",
        "resources/quests/quest_a.tres",
        "resources/quests/quest_b.tres",
        "resources/quests/quest_c.tres",
    ):
        full = os.path.join(PROJECT_DIR, rel)
        assert os.path.isfile(full), f"Expected {full} to exist"


def test_objective_script_class_and_exports(harness_results):
    _require(harness_results, "objective_script_loaded")
    _require(harness_results, "objective_class_name")
    _require(harness_results, "export_description")
    _require(harness_results, "export_target_count")
    _require(harness_results, "export_current_count")


def test_quest_script_class_and_exports(harness_results):
    _require(harness_results, "quest_script_loaded")
    _require(harness_results, "quest_class_name")
    _require(harness_results, "export_id")
    _require(harness_results, "export_title")
    _require(harness_results, "export_description")
    _require(harness_results, "export_objectives")
    _require(harness_results, "export_prerequisite_quest_ids")
    _require(harness_results, "export_reward_gold")
    _require(harness_results, "export_reward_items")


def test_quest_resources_loaded_and_chained(harness_results):
    _require(harness_results, "quest_a_loaded")
    _require(harness_results, "quest_b_loaded")
    _require(harness_results, "quest_c_loaded")
    _require(harness_results, "quest_a_id")
    _require(harness_results, "quest_a_has_objective")
    _require(harness_results, "quest_b_prereqs")
    _require(harness_results, "quest_c_prereqs")


def test_quest_manager_autoloaded(harness_results):
    _require(harness_results, "quest_manager_autoloaded")


def test_prerequisite_gating(harness_results):
    _require(harness_results, "can_start_quest_a_initial")
    _require(harness_results, "can_start_quest_b_initial")
    _require(harness_results, "can_start_quest_b_after_a")


def test_start_quest_emits_signal(harness_results):
    _require(harness_results, "start_quest_a_returns_true")
    _require(harness_results, "quest_started_signal_quest_a")


def test_progress_reporting(harness_results):
    _require(harness_results, "quest_a_progress_before")
    _require(harness_results, "quest_progress_signal_emitted")
    _require(harness_results, "quest_a_progress_after")
    _require(harness_results, "quest_a_is_complete")
    # Every objective_capped_* assertion must pass.
    capped = [
        k for k in harness_results["results"]
        if k.startswith("objective_capped_")
    ]
    assert capped, "Harness did not record any objective_capped_* assertions"
    for name in capped:
        _require(harness_results, name)


def test_complete_quest_behaviour(harness_results):
    _require(harness_results, "complete_quest_a_returns_true")
    _require(harness_results, "quest_completed_signal_quest_a")
    _require(harness_results, "complete_quest_b_rejected")
