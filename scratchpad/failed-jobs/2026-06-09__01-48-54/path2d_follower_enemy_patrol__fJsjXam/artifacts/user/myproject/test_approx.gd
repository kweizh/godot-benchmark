extends SceneTree
func _init():
    print("approx: ", is_equal_approx(1.0, 1.0000001))
    quit()
