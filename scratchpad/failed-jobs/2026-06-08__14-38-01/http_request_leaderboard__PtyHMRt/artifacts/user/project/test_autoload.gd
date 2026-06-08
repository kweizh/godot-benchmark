extends SceneTree

func _init() -> void:
	# Wait a frame for autoloads to be initialized
	await process_frame
	
	var client = root.get_node_or_null("LeaderboardClient")
	if client:
		print("SUCCESS: Autoload LeaderboardClient found in tree!")
		if client is LeaderboardClient:
			print("SUCCESS: client is LeaderboardClient")
		else:
			print("FAILED: client is NOT LeaderboardClient")
	else:
		print("FAILED: Autoload LeaderboardClient NOT found!")
	
	quit()
