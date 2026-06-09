extends SceneTree

func _init():
    var scene = load("res://scenes/PatrolEnemy.tscn")
    var patrol = scene.instantiate()
    var root = Node.new()
    root.add_child(patrol)
    
    patrol.load_waypoints("res://data/waypoints.json")
    patrol.set_speed(100.0)
    patrol.set_mode("loop")
    patrol.set_direction(1)
    
    patrol.progress_changed.connect(func(ratio): print("crossed: ", ratio))
    
    # Total length is 900.
    patrol.tick(8.0) # 800px. Crosses 1/3, 2/3.
    print("progress: ", patrol._path_follow.progress)
    
    print("tick 2")
    patrol.tick(2.0) # 1000px. Crosses 1.0. Wraps. Remaining = 100.
    print("progress: ", patrol._path_follow.progress)
    
    quit()
