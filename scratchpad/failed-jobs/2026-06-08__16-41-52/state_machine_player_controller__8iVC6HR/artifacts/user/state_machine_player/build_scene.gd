extends SceneTree

func _init() -> void:
	call_deferred("_build")

func _build() -> void:
	# Load State.gd FIRST so class_name State is registered
	var StateScript := load("res://scripts/states/State.gd")
	if StateScript == null:
		printerr("FAILED to load State.gd")
		quit()
		return
	print("State.gd loaded OK")

	# Now load the rest
	var SMScript := load("res://scripts/StateMachine.gd")
	if SMScript == null:
		printerr("FAILED to load StateMachine.gd")
	else:
		print("StateMachine.gd loaded OK")

	var IdleScript := load("res://scripts/states/IdleState.gd")
	if IdleScript == null:
		printerr("FAILED to load IdleState.gd")
	else:
		print("IdleState.gd loaded OK")

	var RunScript := load("res://scripts/states/RunState.gd")
	if RunScript == null:
		printerr("FAILED to load RunState.gd")
	else:
		print("RunState.gd loaded OK")

	var JumpScript := load("res://scripts/states/JumpState.gd")
	if JumpScript == null:
		printerr("FAILED to load JumpState.gd")
	else:
		print("JumpState.gd loaded OK")

	var FallScript := load("res://scripts/states/FallState.gd")
	if FallScript == null:
		printerr("FAILED to load FallState.gd")
	else:
		print("FallState.gd loaded OK")

	var AttackScript := load("res://scripts/states/AttackState.gd")
	if AttackScript == null:
		printerr("FAILED to load AttackState.gd")
	else:
		print("AttackState.gd loaded OK")

	var PlayerScript := load("res://scripts/Player.gd")
	if PlayerScript == null:
		printerr("FAILED to load Player.gd")
	else:
		print("Player.gd loaded OK")

	quit()
