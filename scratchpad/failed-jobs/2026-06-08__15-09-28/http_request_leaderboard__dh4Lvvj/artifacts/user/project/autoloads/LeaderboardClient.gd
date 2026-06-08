extends Node
class_name LeaderboardClient

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export var base_url: String = "http://localhost:8765"
@export var max_retries: int = 2

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal leaderboard_fetched(entries: Array)
signal score_submitted(success: bool, server_rank: int)
signal request_failed(endpoint: String, code: int)

# ---------------------------------------------------------------------------
# Internal types
# ---------------------------------------------------------------------------

## One pending call stored in the queue.
class _Job:
	var endpoint: String        # e.g. "/top?limit=10"
	var method: int             # HTTPClient.METHOD_GET / METHOD_POST
	var body: String            # JSON-encoded body (empty for GET)
	var headers: PackedStringArray
	var attempt: int            # how many times we have already tried
	var on_success: Callable    # fn(body_text: String) -> void
	var on_failure: Callable    # fn(code: int) -> void

	func _init(
		p_endpoint: String,
		p_method: int,
		p_body: String,
		p_headers: PackedStringArray,
		p_on_success: Callable,
		p_on_failure: Callable
	) -> void:
		endpoint  = p_endpoint
		method    = p_method
		body      = p_body
		headers   = p_headers
		attempt   = 0
		on_success = p_on_success
		on_failure = p_on_failure

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _http: HTTPRequest
var _queue: Array = []          # Array[_Job]
var _busy: bool   = false
var _current_job: _Job = null
var _retry_timer: SceneTreeTimer = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = false
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## GET {base_url}/top?limit=<n>
## Emits leaderboard_fetched(entries) on success, request_failed on exhaustion.
func fetch_top(limit: int = 10) -> void:
	var endpoint := "/top?limit=%d" % limit
	var job := _Job.new(
		endpoint,
		HTTPClient.METHOD_GET,
		"",
		PackedStringArray(["Accept: application/json"]),
		func(text: String) -> void:
			var parsed = JSON.parse_string(text)
			if parsed == null or not (parsed is Array):
				emit_signal("request_failed", endpoint, -1)
				return
			var entries: Array = []
			for item in parsed:
				if item is Dictionary:
					entries.append({"name": str(item.get("name", "")),
									"score": int(item.get("score", 0))})
			emit_signal("leaderboard_fetched", entries),
		func(code: int) -> void:
			emit_signal("request_failed", endpoint, code)
	)
	_enqueue(job)


## POST {"name": ..., "score": ...} to {base_url}/submit
## Emits score_submitted(true, rank) on success, score_submitted(false, -1)
## + request_failed on exhaustion.
func submit_score(player_name: String, score: int) -> void:
	var endpoint := "/submit"
	var body_dict := {"name": player_name, "score": score}
	var body_text := JSON.stringify(body_dict)
	var job := _Job.new(
		endpoint,
		HTTPClient.METHOD_POST,
		body_text,
		PackedStringArray([
			"Content-Type: application/json",
			"Accept: application/json"
		]),
		func(text: String) -> void:
			var parsed = JSON.parse_string(text)
			var rank := -1
			if parsed is Dictionary and parsed.has("rank"):
				rank = int(parsed["rank"])
			emit_signal("score_submitted", true, rank),
		func(code: int) -> void:
			emit_signal("score_submitted", false, -1)
			emit_signal("request_failed", endpoint, code)
	)
	_enqueue(job)

# ---------------------------------------------------------------------------
# Queue management
# ---------------------------------------------------------------------------

func _enqueue(job: _Job) -> void:
	_queue.append(job)
	_pump()


func _pump() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	_current_job = _queue.pop_front()
	_dispatch(_current_job)


func _dispatch(job: _Job) -> void:
	var url := base_url + job.endpoint
	var err := _http.request(url, job.headers, job.method, job.body)
	if err != OK:
		# Treat local dispatch error the same as a transport error (code 0).
		_handle_failure(job, 0)

# ---------------------------------------------------------------------------
# HTTPRequest callback
# ---------------------------------------------------------------------------

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var job := _current_job
	# Transport error or non-2xx HTTP status
	var is_transport_error := (result != HTTPRequest.RESULT_SUCCESS)
	var is_http_error := (response_code < 200 or response_code >= 300)

	if is_transport_error or is_http_error:
		var code := response_code if not is_transport_error else 0
		_handle_failure(job, code)
		return

	# Success path
	_finish_job()
	job.on_success.call(body.get_string_from_utf8())


## Called on any error for the current job; handles retry / exhaustion logic.
func _handle_failure(job: _Job, code: int) -> void:
	job.attempt += 1
	if job.attempt <= max_retries:
		var delay := 0.05 * pow(2.0, job.attempt - 1)   # 0.05 s, 0.1 s, 0.2 s …
		_retry_timer = get_tree().create_timer(delay)
		_retry_timer.timeout.connect(func() -> void:
			_retry_timer = null
			_dispatch(job),
			CONNECT_ONE_SHOT
		)
	else:
		_finish_job()
		job.on_failure.call(code)


## Release the busy lock and process the next queued job.
func _finish_job() -> void:
	_current_job = null
	_busy = false
	_pump()
