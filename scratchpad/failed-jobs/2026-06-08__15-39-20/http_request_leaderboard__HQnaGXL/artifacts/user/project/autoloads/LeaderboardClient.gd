class_name LeaderboardClient
extends Node

signal leaderboard_fetched(entries: Array)
signal score_submitted(success: bool, server_rank: int)
signal request_failed(endpoint: String, code: int)

@export var base_url: String = "http://localhost:8765"
@export var max_retries: int = 2

var http_request: HTTPRequest
var request_queue: Array = []
var is_requesting: bool = false

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func fetch_top(limit: int = 10):
	var url = base_url + "/top?limit=" + str(limit)
	_enqueue_request({
		"type": "fetch_top",
		"endpoint": "/top",
		"url": url,
		"method": HTTPClient.METHOD_GET,
		"headers": [],
		"body": "",
		"retries": 0,
		"backoff": 0.05
	})

func submit_score(name: String, score: int):
	var url = base_url + "/submit"
	var body = JSON.stringify({"name": name, "score": score})
	var headers = ["Content-Type: application/json"]
	_enqueue_request({
		"type": "submit_score",
		"endpoint": "/submit",
		"url": url,
		"method": HTTPClient.METHOD_POST,
		"headers": headers,
		"body": body,
		"retries": 0,
		"backoff": 0.05
	})

func _enqueue_request(req: Dictionary):
	request_queue.append(req)
	_process_queue()

func _process_queue():
	if is_requesting or request_queue.is_empty():
		return
	
	is_requesting = true
	var req = request_queue[0]
	
	var err = http_request.request(req["url"], req["headers"], req["method"], req["body"])
	if err != OK:
		call_deferred("_on_request_completed", HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if request_queue.is_empty():
		is_requesting = false
		return
		
	var req = request_queue[0]
	var success = (result == HTTPRequest.RESULT_SUCCESS) and (response_code >= 200 and response_code < 300)
	
	if success:
		request_queue.pop_front()
		is_requesting = false
		_handle_success(req, body)
		_process_queue()
	else:
		if req["retries"] < max_retries:
			req["retries"] += 1
			var wait_time = req["backoff"]
			req["backoff"] *= 2.0
			await get_tree().create_timer(wait_time).timeout
			is_requesting = false
			_process_queue()
		else:
			request_queue.pop_front()
			is_requesting = false
			request_failed.emit(req["endpoint"], response_code)
			_handle_failure(req)
			_process_queue()

func _handle_success(req: Dictionary, body: PackedByteArray):
	var data = JSON.parse_string(body.get_string_from_utf8())
	if req["type"] == "fetch_top":
		if typeof(data) == TYPE_ARRAY:
			leaderboard_fetched.emit(data)
		else:
			leaderboard_fetched.emit([])
	elif req["type"] == "submit_score":
		var rank = -1
		if typeof(data) == TYPE_DICTIONARY and data.has("rank"):
			rank = int(data["rank"])
		score_submitted.emit(true, rank)

func _handle_failure(req: Dictionary):
	if req["type"] == "submit_score":
		score_submitted.emit(false, -1)
