extends SceneTree

func _init() -> void:
	await process_frame
	
	var client = root.get_node_or_null("LeaderboardClient")
	if not client:
		print("FAILED: LeaderboardClient autoload not found!")
		quit(1)
		return
	
	# Set base_url to a non-existent port to force connection failure
	client.base_url = "http://localhost:9999"
	client.max_retries = 2
	
	print("Connecting signals...")
	client.leaderboard_fetched.connect(_on_leaderboard_fetched)
	client.score_submitted.connect(_on_score_submitted)
	client.request_failed.connect(_on_request_failed)
	
	print("Calling fetch_top(10) and submit_score('Charlie', 80) concurrently on bad URL...")
	client.fetch_top(10)
	client.submit_score("Charlie", 80)
	
	# Wait for 5 seconds to let retries finish
	await create_timer(5.0).timeout
	print("Test finished!")
	quit()

func _on_leaderboard_fetched(entries: Array) -> void:
	print("SIGNAL: leaderboard_fetched: ", entries)

func _on_score_submitted(success: bool, server_rank: int) -> void:
	print("SIGNAL: score_submitted: success=", success, ", rank=", server_rank)

func _on_request_failed(endpoint: String, code: int) -> void:
	print("SIGNAL: request_failed: endpoint=", endpoint, ", code=", code)
