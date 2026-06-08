extends SceneTree

func _init():
	var bus = root.get_node("/root/Bus")
	if bus == null:
		print("Bus is null")
		quit()
		return
	var obj = Node.new()
	
	bus.subscribe("test", func(payload):
		print("called with ", payload)
	)
	bus.subscribe("test2", obj.set_name)
	
	print("count test2: ", bus.subscription_count("test2"))
	obj.free()
	print("count test2 after free: ", bus.subscription_count("test2"))
	
	bus.publish("test", "hello")
	bus.publish("test2", "hello")
	
	print("Done")
	quit()
