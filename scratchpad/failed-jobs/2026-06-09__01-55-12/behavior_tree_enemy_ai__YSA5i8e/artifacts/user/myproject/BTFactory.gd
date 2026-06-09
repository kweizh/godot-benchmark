class_name BTFactory
extends RefCounted

static func build_enemy_tree() -> BTNode:
	# Branch 1: Flee when unhealthy
	# BTInverter wrapping IsHealthy
	var is_healthy := IsHealthy.new()
	var inverter := BTInverter.new()
	inverter.child = is_healthy

	var flee := FleeAction.new()

	var flee_sequence := BTSequence.new()
	flee_sequence.children.append(inverter)
	flee_sequence.children.append(flee)

	# Branch 2: Patrol -> Chase -> Attack
	var patrol := PatrolUntilSpotted.new()
	var chase := ChasePlayer.new()
	var attack := AttackIfInRange.new()

	var engage_sequence := BTSequence.new()
	engage_sequence.children.append(patrol)
	engage_sequence.children.append(chase)
	engage_sequence.children.append(attack)

	# Root selector
	var root := BTSelector.new()
	root.children.append(flee_sequence)
	root.children.append(engage_sequence)

	return root
