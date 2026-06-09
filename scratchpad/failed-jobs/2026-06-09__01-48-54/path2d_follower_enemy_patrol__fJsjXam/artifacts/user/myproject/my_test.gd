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
    
    # Total length is 300+300+300 = 900.
    # Waypoints: 0, 1/3, 2/3, 1.
    print("tick 1")
    patrol.tick(2.0) # 200px. No crossing (200 < 300)
    print("progress: ", patrol._path_follow.progress)
    
    print("tick 2")
    patrol.tick(2.0) # 400px. Crosses 300 (1/3)
    print("progress: ", patrol._path_follow.progress)
    
    print("tick 3")
    patrol.tick(6.0) # 1000px total. Crosses 600 (2/3), 900 (1.0), and reverses to 800.
                     # Crosses 900 again? Wait, reversal. 
                     # Reaches 900, emits 1.0. Reverses. Remaining = 100. 
                     # Crosses nothing backward.
    print("progress: ", patrol._path_follow.progress)
    
    quit()
