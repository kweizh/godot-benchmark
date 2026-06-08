extends SceneTree
func _init():
    print("Testing...")
    if typeof(LeaderboardClient) == TYPE_OBJECT:
        print("LeaderboardClient is object")
    quit()
