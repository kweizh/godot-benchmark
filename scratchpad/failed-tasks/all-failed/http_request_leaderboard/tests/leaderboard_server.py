"""Tiny real HTTP server for the http_request_leaderboard verifier.

This server is intentionally simple — it runs on top of Python's stdlib
`http.server` module and exposes the endpoints described in `bootstrap/task.json`.

Endpoints:
    GET  /top              -> 200 JSON leaderboard (length 2)
    POST /submit           -> 200 {"rank": 3}  and appends to LOG_FILE
    GET  /reset            -> 200 "ok"; resets the failure counter
    GET  /set_top_failures -> 200; query param `count=<int>` sets how many
                              future /top calls should respond with 500
    GET  /healthz          -> 200 "ok"

NOTE: This is a REAL HTTP server. The Godot client under test must use
HTTPRequest to talk to it; mocking HTTPRequest is forbidden.
"""
from __future__ import annotations

import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


LOG_FILE = os.environ.get("LEADERBOARD_SERVER_LOG", "/tmp/leaderboard_server.log")

_state_lock = threading.Lock()
_state = {
    "top_failures_remaining": 0,
    "submit_count": 0,
}


def _log(message: str) -> None:
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(message + "\n")
    except OSError:
        # Logging is best-effort; never fail the request because of disk issues.
        pass


class _Handler(BaseHTTPRequestHandler):
    # Silence the default per-request stderr noise.
    def log_message(self, format: str, *args) -> None:  # type: ignore[override]
        return

    # ----- helpers -----------------------------------------------------
    def _send_json(self, status: int, payload) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _send_text(self, status: int, text: str) -> None:
        body = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    # ----- routing -----------------------------------------------------
    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        if path == "/healthz":
            self._send_text(200, "ok")
            return

        if path == "/reset":
            with _state_lock:
                _state["top_failures_remaining"] = 0
                _state["submit_count"] = 0
            _log("RESET")
            self._send_text(200, "ok")
            return

        if path == "/set_top_failures":
            try:
                count = int(params.get("count", ["0"])[0])
            except ValueError:
                count = 0
            with _state_lock:
                _state["top_failures_remaining"] = max(0, count)
            _log(f"SET_TOP_FAILURES count={count}")
            self._send_text(200, "ok")
            return

        if path == "/top":
            with _state_lock:
                remaining = _state["top_failures_remaining"]
                if remaining > 0:
                    _state["top_failures_remaining"] = remaining - 1
                    _log(f"GET /top -> 500 (remaining_failures={remaining - 1})")
                    self._send_text(500, "fail")
                    return
            payload = [
                {"name": "Alice", "score": 300},
                {"name": "Bob", "score": 200},
            ]
            _log("GET /top -> 200")
            self._send_json(200, payload)
            return

        if path == "/fail":
            # Always returns 500. Useful for misc. error-path tests.
            _log("GET /fail -> 500")
            self._send_text(500, "fail")
            return

        self._send_text(404, "not found")

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path

        if path != "/submit":
            self._send_text(404, "not found")
            return

        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length) if length > 0 else b""
        try:
            payload = json.loads(raw.decode("utf-8") or "{}")
        except (UnicodeDecodeError, json.JSONDecodeError):
            self._send_text(400, "invalid json")
            return

        name = payload.get("name", "")
        score = payload.get("score", 0)
        with _state_lock:
            _state["submit_count"] += 1
        _log(f"POST /submit name={name} score={score}")
        self._send_json(200, {"rank": 3})


def main(argv: list[str]) -> int:
    host = "127.0.0.1"
    port = 8765
    if len(argv) > 1:
        port = int(argv[1])
    # Reset log file on each launch so harness checks see fresh data.
    try:
        open(LOG_FILE, "w", encoding="utf-8").close()
    except OSError:
        pass
    httpd = ThreadingHTTPServer((host, port), _Handler)
    print(f"leaderboard_server listening on http://{host}:{port}", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
