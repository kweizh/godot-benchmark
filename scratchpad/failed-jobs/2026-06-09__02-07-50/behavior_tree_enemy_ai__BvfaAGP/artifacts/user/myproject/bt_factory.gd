class_name BTFactory
extends RefCounted

static func build_enemy_tree() -> BTNode:
	var flee_sequence := BTSequence.new()
	var inverter := BTInverter.new()
	inverter.child = IsHealthy.new()
	flee_sequence.children.append(inverter)
	flee_sequence.children.append(FleeAction.new())

	var combat_sequence := BTSequence.new()
	combat_sequence.children.append(PatrolUntilSpotted.new())
	combat_sequence.children.append(ChasePlayer.new())
	combat_sequence.children.append(AttackIfInRange.new())

	var root := BTSelector.new()
	root.children.append(flee_sequence)
	root.children.append(combat_sequence)

	return root
