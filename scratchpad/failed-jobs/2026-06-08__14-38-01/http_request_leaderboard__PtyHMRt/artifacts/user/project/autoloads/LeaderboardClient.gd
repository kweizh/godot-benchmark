extends Node
class_name LeaderboardClient

# Exports
@export var base_url: String = "http://localhost:8765"
@export var max_retries: int = 2

# Signals
signal leaderboard_fetched(entries: Array)
signal score_submitted(success: bool, server_rank: int)
signal request_failed(endpoint: String, code: int)

# Internal state
var _http_request: HTTPRequest
var _queue: Array = []
var _is_processing: bool = false

func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

func fetch_top(limit: int = 10) -> void:
	var endpoint = "/top?limit=" + str(limit)
	var url = base_url + endpoint
	var req = {
		"type": "fetch_top",
		"url": url,
		"endpoint": endpoint,
		"headers": PackedStringArray(),
		"method": HTTPClient.METHOD_GET,
		"body": "",
		"retry_count": 0
	}
	_queue.append(req)
	_process_queue()

func submit_score(name: String, score: int) -> void:
	var endpoint = "/submit"
	var url = base_url + endpoint
	var headers = PackedStringArray(["Content-Type: application/json"])
	var body = JSON.stringify({"name": name, "score": score})
	var req = {
		"type": "submit_score",
		"url": url,
		"endpoint": endpoint,
		"headers": headers,
		"method": HTTPClient.METHOD_POST,
		"body": body,
		"retry_count": 0
	}
	_queue.append(req)
	_process_queue()

func _process_queue() -> void:
	if _is_processing or _queue.is_empty():
		return
	
	_is_processing = true
	var req = _queue[0]
	_send_request(req)

func _send_request(req: Dictionary) -> void:
	var err = _http_request.request(req["url"], req["headers"], req["method"], req["body"])
	if err != OK:
		_handle_failure(req, 0)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _queue.is_empty():
		return
	
	var req = _queue[0]
	var is_success = (result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300)
	
	if is_success:
		var body_str = body.get_string_from_utf8()
		var data = JSON.parse_string(body_str)
		
		if req["type"] == "fetch_top":
			if data is Array:
				var entries: Array = []
				for item in data:
					if item is Dictionary:
						entries.append({
							"name": str(item.get("name", "")),
							"score": int(item.get("score", 0))
						})
				leaderboard_fetched.emit(entries)
				_queue.pop_front()
				_is_processing = false
				_process_queue()
			else:
				# Invalid JSON structure
				request_failed.emit(req["endpoint"], response_code)
				_queue.pop_front()
				_is_processing = false
				_process_queue()
				
		elif req["type"] == "submit_score":
			if data is Dictionary and data.has("rank"):
				var rank = int(data["rank"])
				score_submitted.emit(true, rank)
				_queue.pop_front()
				_is_processing = false
				_process_queue()
			else:
				# Invalid JSON structure
				request_failed.emit(req["endpoint"], response_code)
				score_submitted.emit(false, -1)
				_queue.pop_front()
				_is_processing = false
				_process_queue()
	else:
		_handle_failure(req, response_code)

func _handle_failure(req: Dictionary, response_code: int) -> void:
	if req["retry_count"] < max_retries:
		req["retry_count"] += 1
		var delay = 0.05 * pow(2, req["retry_count"] - 1)
		await get_tree().create_timer(delay).timeout
		
		# Re-issue request
		var err = _http_request.request(req["url"], req["headers"], req["method"], req["body"])
		if err != OK:
			_handle_failure(req, 0)
	else:
		# Retries exhausted
		request_failed.emit(req["endpoint"], response_code)
		if req["type"] == "submit_score":
			score_submitted.emit(false, -1)
		
		_queue.pop_front()
		_is_processing = false
		_process_queue()
