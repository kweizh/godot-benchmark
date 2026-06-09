extends SceneTree

func _init():
    var tree = BTFactory.build_enemy_tree()
    print("Tree built successfully")
    quit()
