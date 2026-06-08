extends SceneTree
func _init():
    var c = Camera2D.new()
    print("Camera properties:")
    for p in c.get_property_list():
        if p.name in ["current", "enabled", "is_current"]:
            print(p.name)
    quit()
