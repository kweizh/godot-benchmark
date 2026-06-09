extends RefCounted
class_name BTFactory

static func build_enemy_tree() -> BTNode:
	# Branch 1: Flee when unhealthy
	var is_healthy: IsHealthy = IsHealthy.new()
	var inverter: BTInverter = BTInverter.new()
	inverter.child = is_healthy
	var flee: FleeAction = FleeAction.new()
	var flee_sequence: BTSequence = BTSequence.new()
	flee_sequence.children = [inverter, flee]

	# Branch 2: Patrol -> Chase -> Attack
	var patrol: PatrolUntilSpotted = PatrolUntilSpotted.new()
	var chase: ChasePlayer = ChasePlayer.new()
	var attack: AttackIfInRange = AttackIfInRange.new()
	var combat_sequence: BTSequence = BTSequence.new()
	combat_sequence.children = [patrol, chase, attack]

	# Root selector
	var root: BTSelector = BTSelector.new()
	root.children = [flee_sequence, combat_sequence]

	return root
