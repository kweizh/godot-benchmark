extends Node

class_name LeaderboardClient

## Base URL for the leaderboard server.
@export var base_url: String = "http://localhost:8765"

## Maximum number of retry attempts on failure.
@export var max_retries: int = 2

## Emitted when the top scores are successfully fetched.
signal leaderboard_fetched(entries: Array)

## Emitted when a score submission completes.
## On success: success=true, server_rank=<rank from server>.
## On failure after retries: success=false, server_rank=-1.
signal score_submitted(success: bool, server_rank: int)

## Emitted when a request fails after all retries are exhausted.
signal request_failed(endpoint: String, code: int)

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _http: HTTPRequest
var _queue: Array = []
var _busy: bool = false
var _current_task: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Fetches the top [limit] entries from the leaderboard.
## Emits [signal leaderboard_fetched] on success.
func fetch_top(limit: int = 10) -> void:
	_enqueue({
		method = HTTPClient.METHOD_GET,
		endpoint = "/top?limit=%d" % limit,
		response_handler = _handle_fetch_top_response,
		error_handler = func(ep, code):
			request_failed.emit(ep, code)
	})

## Submits a score for [name] to the server.
## Emits [signal score_submitted] on success or after final failure.
func submit_score(player_name: String, score: int) -> void:
	var body: String = JSON.stringify({name = player_name, score = score})
	_enqueue({
		method = HTTPClient.METHOD_POST,
		endpoint = "/submit",
		body = body,
		headers = ["Content-Type: application/json"],
		response_handler = _handle_submit_response,
		error_handler = func(ep, code):
			request_failed.emit(ep, code)
			score_submitted.emit(false, -1)
	})

# ---------------------------------------------------------------------------
# Queue management
# ---------------------------------------------------------------------------

func _enqueue(task: Dictionary) -> void:
	_queue.push_back(task)
	_process_queue()

func _process_queue() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	var task: Dictionary = _queue.pop_front()
	_send_request(task, 0)

# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

func _send_request(task: Dictionary, attempt: int) -> void:
	task["_attempt"] = attempt
	_current_task = task
	var url: String = base_url + task.endpoint
	var err: int = _http.request(url, task.get("headers", []), task.get("method", HTTPClient.METHOD_GET), task.get("body", ""))
	if err != OK:
		_handle_retry(task, attempt, -1)

func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if response_code >= 200 and response_code < 300:
		var task: Dictionary = _current_task
		_busy = false
		_current_task = {}
		task.response_handler.call(response_code, body)
		_process_queue()
	else:
		var task: Dictionary = _current_task
		_handle_retry(task, task.get("_attempt", 0), response_code)

func _handle_retry(task: Dictionary, attempt: int, code: int) -> void:
	if attempt < max_retries:
		# Exponential backoff: 0.05, 0.1, 0.2, ...
		var delay: float = 0.05 * pow(2, attempt)
		await get_tree().create_timer(delay).timeout
		_send_request(task, attempt + 1)
	else:
		_busy = false
		_current_task = {}
		task.error_handler.call(task.endpoint, code)
		_process_queue()

# ---------------------------------------------------------------------------
# Response handlers
# ---------------------------------------------------------------------------

func _handle_fetch_top_response(_code: int, body: PackedByteArray) -> void:
	var text: String = body.get_string_from_utf8()
	var json: Variant = JSON.parse_string(text)
	var entries: Array = []
	if json != null and json is Array:
		for item in json:
			if item is Dictionary and item.has("name") and item.has("score"):
				entries.append({
					name = item["name"],
					score = int(item["score"])
				})
	leaderboard_fetched.emit(entries)

func _handle_submit_response(_code: int, body: PackedByteArray) -> void:
	var text: String = body.get_string_from_utf8()
	var json: Variant = JSON.parse_string(text)
	var rank: int = -1
	if json != null and json is Dictionary and json.has("rank"):
		rank = int(json["rank"])
	score_submitted.emit(true, rank)
