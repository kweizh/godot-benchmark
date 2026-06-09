extends SceneTree

func _init():
    var scene = load("res://scenes/PatrolEnemy.tscn")
    var patrol = scene.instantiate()
    var root = Node.new()
    root.add_child(patrol)
    
    patrol.load_waypoints("res://data/waypoints.json")
    patrol.set_speed(100.0)
    patrol.set_mode("loop")
    patrol.set_direction(-1)
    
    patrol.progress_changed.connect(func(ratio): print("crossed: ", ratio))
    
    print("tick 1")
    patrol.tick(2.0) # 200px backward. Crosses 0.0. Wraps to 900. Remaining = 200. Progress = 700.
    print("progress: ", patrol._path_follow.progress)
    
    quit()
