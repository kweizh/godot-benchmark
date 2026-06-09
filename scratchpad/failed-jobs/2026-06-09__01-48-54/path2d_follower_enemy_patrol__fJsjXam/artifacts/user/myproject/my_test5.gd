extends SceneTree

func _init():
    var scene = load("res://scenes/PatrolEnemy.tscn")
    var patrol = scene.instantiate()
    var root = Node.new()
    root.add_child(patrol)
    
    patrol.load_waypoints("res://data/waypoints.json")
    patrol.set_speed(100.0)
    patrol.set_mode("pingpong")
    patrol.set_direction(1)
    
    patrol.progress_changed.connect(func(ratio): print("crossed: ", ratio))
    
    patrol._path_follow.progress = 800.0
    
    print("tick 1")
    patrol.tick(2.0) # 200px forward. Hits 900 (emits 1.0), reverses, remaining 100. Ends at 800.
    print("progress: ", patrol._path_follow.progress)
    
    quit()
