extends SceneTree

func _init() -> void:
	_ready()

func _ready() -> void:
	run_tests()
	quit()

func run_tests() -> void:
	var root: BTNode = BTFactory.build_enemy_tree()
	var results: Array = []

	# --- Scenario 1: Healthy, not spotted, far away ---
	# Expected: PatrolUntilSpotted runs (RUNNING), so root returns RUNNING
	var bb1: Dictionary = {
		"health": 100,
		"healthy_threshold": 50,
		"player_spotted": false,
		"patrol_steps": 0,
		"action": "",
		"distance_to_player": 200.0,
		"attack_range": 10.0,
		"chase_speed": 30.0,
		"attack_damage": 25,
		"last_attack_damage": 0
	}
	var status1: int = root.tick(bb1)
	results.append({"label": "healthy_not_spotted_far", "status": status1, "blackboard": bb1.duplicate()})

	# --- Scenario 2: Healthy, spotted, far away ---
	# Expected: PatrolUntilSpotted returns SUCCESS, ChasePlayer returns RUNNING, root returns RUNNING
	var bb2: Dictionary = {
		"health": 100,
		"healthy_threshold": 50,
		"player_spotted": true,
		"patrol_steps": 0,
		"action": "",
		"distance_to_player": 200.0,
		"attack_range": 10.0,
		"chase_speed": 30.0,
		"attack_damage": 25,
		"last_attack_damage": 0
	}
	var status2: int = root.tick(bb2)
	results.append({"label": "healthy_spotted_far", "status": status2, "blackboard": bb2.duplicate()})

	# --- Scenario 3: Healthy, spotted, in attack range ---
	# Expected: PatrolUntilSpotted returns SUCCESS, ChasePlayer returns SUCCESS, AttackIfInRange returns SUCCESS, root returns SUCCESS
	var bb3: Dictionary = {
		"health": 100,
		"healthy_threshold": 50,
		"player_spotted": true,
		"patrol_steps": 0,
		"action": "",
		"distance_to_player": 5.0,
		"attack_range": 10.0,
		"chase_speed": 30.0,
		"attack_damage": 25,
		"last_attack_damage": 0
	}
	var status3: int = root.tick(bb3)
	results.append({"label": "healthy_spotted_in_range", "status": status3, "blackboard": bb3.duplicate()})

	# --- Scenario 4: Unhealthy ---
	# Expected: IsHealthy returns FAILURE, Inverter returns SUCCESS, FleeAction returns SUCCESS, root returns SUCCESS
	var bb4: Dictionary = {
		"health": 20,
		"healthy_threshold": 50,
		"player_spotted": false,
		"patrol_steps": 0,
		"action": "",
		"distance_to_player": 200.0,
		"attack_range": 10.0,
		"chase_speed": 30.0,
		"attack_damage": 25,
		"last_attack_damage": 0
	}
	var status4: int = root.tick(bb4)
	results.append({"label": "unhealthy", "status": status4, "blackboard": bb4.duplicate()})

	# --- Scenario 5: Healthy, spotted, just outside attack range ---
	# Expected: PatrolUntilSpotted returns SUCCESS, ChasePlayer returns RUNNING, root returns RUNNING
	var bb5: Dictionary = {
		"health": 100,
		"healthy_threshold": 50,
		"player_spotted": true,
		"patrol_steps": 0,
		"action": "",
		"distance_to_player": 15.0,
		"attack_range": 10.0,
		"chase_speed": 30.0,
		"attack_damage": 25,
		"last_attack_damage": 0
	}
	var status5: int = root.tick(bb5)
	results.append({"label": "healthy_spotted_near", "status": status5, "blackboard": bb5.duplicate()})

	# --- Scenario 6: Multiple patrol ticks ---
	var bb6: Dictionary = {
		"health": 100,
		"healthy_threshold": 50,
		"player_spotted": false,
		"patrol_steps": 5,
		"action": "",
		"distance_to_player": 200.0,
		"attack_range": 10.0,
		"chase_speed": 30.0,
		"attack_damage": 25,
		"last_attack_damage": 0
	}
	var status6: int = root.tick(bb6)
	results.append({"label": "patrol_tick", "status": status6, "blackboard": bb6.duplicate()})

	print("BT_RESULTS:" + JSON.stringify(results))
