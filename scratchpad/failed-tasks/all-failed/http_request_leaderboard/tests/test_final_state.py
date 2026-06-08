import os
import re
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

import pytest


PROJECT_DIR = "/home/user/project"
ZEALT_TESTS_DIR = os.path.join(PROJECT_DIR, "_zealt_tests")
HARNESS_SRC_DIR = "/tests"

HARNESS_FILES = [
    "test_harness.gd",
    "test_harness.tscn",
]

SERVER_SCRIPT = os.path.join(HARNESS_SRC_DIR, "leaderboard_server.py")
SERVER_HOST = "127.0.0.1"
SERVER_PORT = 8765
SERVER_LOG = "/tmp/leaderboard_server.log"

GODOT_TEST_LOG = os.path.join(PROJECT_DIR, "godot_test.log")
XDG_DATA_HOME = "/tmp/godot_test_xdg_http"


def _godot_env() -> dict:
    env = os.environ.copy()
    env["XDG_DATA_HOME"] = XDG_DATA_HOME
    env["LEADERBOARD_SERVER_LOG"] = SERVER_LOG
    env.pop("DISPLAY", None)
    return env


def _reset_user_data() -> None:
    if os.path.isdir(XDG_DATA_HOME):
        shutil.rmtree(XDG_DATA_HOME, ignore_errors=True)
    os.makedirs(XDG_DATA_HOME, exist_ok=True)


def _install_harnesses() -> None:
    os.makedirs(ZEALT_TESTS_DIR, exist_ok=True)
    for fname in HARNESS_FILES:
        src = os.path.join(HARNESS_SRC_DIR, fname)
        dst = os.path.join(ZEALT_TESTS_DIR, fname)
        assert os.path.isfile(src), f"Harness source missing: {src}"
        shutil.copyfile(src, dst)


def _read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def _wait_for_port(host: str, port: int, timeout: float = 10.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=1.0):
                return True
        except OSError:
            time.sleep(0.1)
    return False


@pytest.fixture(scope="module", autouse=True)
def _http_server():
    """Start the real Python HTTP server backing the leaderboard endpoints."""
    assert os.path.isfile(SERVER_SCRIPT), f"Missing test server at {SERVER_SCRIPT}"
    # Make sure no leftover process is bound to the port.
    if _wait_for_port(SERVER_HOST, SERVER_PORT, timeout=0.5):
        pytest.fail(
            f"Port {SERVER_PORT} is already in use before test server startup."
        )

    proc = subprocess.Popen(
        [sys.executable, SERVER_SCRIPT, str(SERVER_PORT)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env={**os.environ, "LEADERBOARD_SERVER_LOG": SERVER_LOG},
    )
    try:
        assert _wait_for_port(SERVER_HOST, SERVER_PORT, timeout=10.0), (
            "Test HTTP server failed to start within 10 seconds. "
            f"Output:\n{(proc.stdout.read() if proc.stdout else b'').decode(errors='replace')}"
        )
        yield
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()


@pytest.fixture(scope="module", autouse=True)
def _install_test_harness(_http_server):
    _install_harnesses()
    yield
    shutil.rmtree(ZEALT_TESTS_DIR, ignore_errors=True)


# ---------------------------------------------------------------------------
# Static structure checks
# ---------------------------------------------------------------------------

def test_required_files_exist():
    required = [
        "project.godot",
        "autoloads/LeaderboardClient.gd",
    ]
    for rel in required:
        full = os.path.join(PROJECT_DIR, rel)
        assert os.path.isfile(full), f"Missing required file: {full}"


def test_autoload_registered_in_project_godot():
    content = _read_text(os.path.join(PROJECT_DIR, "project.godot"))
    pattern = re.compile(
        r'^LeaderboardClient\s*=\s*"\*res://autoloads/LeaderboardClient\.gd"\s*$',
        re.MULTILINE,
    )
    assert pattern.search(content), (
        'project.godot must register `LeaderboardClient="*res://autoloads/LeaderboardClient.gd"` '
        "under the [autoload] section."
    )


def test_leaderboard_client_uses_httprequest():
    src = _read_text(os.path.join(PROJECT_DIR, "autoloads/LeaderboardClient.gd"))
    assert "class_name LeaderboardClient" in src, (
        "LeaderboardClient.gd must declare `class_name LeaderboardClient`."
    )
    assert "HTTPRequest" in src, (
        "LeaderboardClient.gd must use the built-in HTTPRequest class."
    )
    # All required signals and methods must be declared somewhere in the script.
    for needle in [
        "signal leaderboard_fetched",
        "signal score_submitted",
        "signal request_failed",
        "func fetch_top",
        "func submit_score",
    ]:
        assert needle in src, (
            f"LeaderboardClient.gd is missing required declaration: `{needle}`"
        )


def test_exports_present():
    src = _read_text(os.path.join(PROJECT_DIR, "autoloads/LeaderboardClient.gd"))
    # Accept either `@export var base_url` / `@export var max_retries`
    # with or without explicit type annotations.
    assert re.search(r"@export\s+var\s+base_url", src), (
        "LeaderboardClient.gd must declare `@export var base_url`."
    )
    assert re.search(r"@export\s+var\s+max_retries", src), (
        "LeaderboardClient.gd must declare `@export var max_retries`."
    )


# ---------------------------------------------------------------------------
# Godot loads project cleanly
# ---------------------------------------------------------------------------

def test_project_loads_without_errors():
    _reset_user_data()
    result = subprocess.run(
        ["godot", "--headless", "--path", PROJECT_DIR, "--quit"],
        capture_output=True,
        text=True,
        timeout=120,
        env=_godot_env(),
    )
    combined = (result.stdout or "") + (result.stderr or "")
    assert result.returncode == 0, (
        f"`godot --quit` exited with code {result.returncode}:\n{combined}"
    )
    for marker in ["SCRIPT ERROR", "Parse Error", "Failed to load"]:
        assert marker not in combined, (
            f"Godot reported '{marker}' while loading the project:\n{combined}"
        )


# ---------------------------------------------------------------------------
# Runtime behavior (uses real HTTP server fixture above)
# ---------------------------------------------------------------------------

def test_runtime_harness_against_real_http_server():
    _reset_user_data()
    # Remove any stale log so we know the harness produced a fresh one.
    if os.path.exists(GODOT_TEST_LOG):
        os.unlink(GODOT_TEST_LOG)

    result = subprocess.run(
        [
            "godot",
            "--headless",
            "--path",
            PROJECT_DIR,
            "res://_zealt_tests/test_harness.tscn",
        ],
        capture_output=True,
        text=True,
        timeout=240,
        env=_godot_env(),
    )
    combined = (result.stdout or "") + (result.stderr or "")
    assert result.returncode == 0, (
        f"Test harness exited with code {result.returncode}:\n{combined}"
    )

    assert os.path.isfile(GODOT_TEST_LOG), (
        f"Harness did not write report file at {GODOT_TEST_LOG}.\n"
        f"Godot stdout/stderr:\n{combined}"
    )

    report = _read_text(GODOT_TEST_LOG)
    required_checks = [
        "autoload_present",
        "signal_leaderboard_fetched",
        "signal_score_submitted",
        "signal_request_failed",
        "method_fetch_top",
        "method_submit_score",
        "fetch_top_happy",
        "submit_score_happy",
        "fetch_top_retry_success",
        "fetch_top_retry_exhaust",
    ]
    for check in required_checks:
        pattern = re.compile(r"^" + re.escape(check) + r"\s+OK\s*$", re.MULTILINE)
        assert pattern.search(report), (
            f"Harness check '{check}' did not pass. Full report:\n{report}\n"
            f"Godot stdout/stderr:\n{combined}"
        )


def test_submit_recorded_in_server_log():
    # Verifies the POST /submit actually hit the real HTTP server (no mocking).
    assert os.path.isfile(SERVER_LOG), f"Server log not found at {SERVER_LOG}"
    log_text = _read_text(SERVER_LOG)
    pattern = re.compile(r"^POST /submit name=Carol score=150\s*$", re.MULTILINE)
    assert pattern.search(log_text), (
        "Expected a real POST /submit for Carol/150 in the server log, "
        f"got:\n{log_text}"
    )
