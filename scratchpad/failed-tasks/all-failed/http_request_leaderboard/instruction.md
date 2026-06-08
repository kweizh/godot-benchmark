# Leaderboard Client (Godot 4)

Build an HTTP-based leaderboard client in the Godot 4 project at `/home/user/project`.

## Acceptance Criteria

- Project path: `/home/user/project`.
- Register an autoload `LeaderboardClient` -> `res://autoloads/LeaderboardClient.gd` with `class_name LeaderboardClient`.
- The script must use the built-in `HTTPRequest` class (no third-party libs, no mocking).
- Exports: `@export var base_url: String = "http://localhost:8765"`, `@export var max_retries: int = 2`.
- Signals: `leaderboard_fetched(entries: Array)`, `score_submitted(success: bool, server_rank: int)`, `request_failed(endpoint: String, code: int)`.
- Methods:
  - `fetch_top(limit: int = 10)` — `GET {base_url}/top?limit=<n>`, parses the JSON array response and emits `leaderboard_fetched` with an `Array` of `{ "name": String, "score": int }` dicts.
  - `submit_score(name: String, score: int)` — `POST` JSON `{"name": ..., "score": ...}` to `{base_url}/submit`, parses `{"rank": <int>}` from the response, and emits `score_submitted(true, rank)` on success.
- Retries: on any non-2xx response (or transport error) retry up to `max_retries` more times with exponential backoff starting at 0.05s (doubling each attempt). When retries are exhausted, emit `request_failed(endpoint, code)` exactly once; in addition, `submit_score` must emit `score_submitted(false, -1)` and `fetch_top` must not emit `leaderboard_fetched`.
- Use a single `HTTPRequest` child created in `_ready()`, and serialize concurrent calls through an internal queue.
- The project must boot under `godot --headless --path /home/user/project` (a minimal main scene is fine).
