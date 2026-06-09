class_name BTFactory
extends RefCounted

static func build_enemy_tree() -> BTNode:
	# Root is a BTSelector
	var root = BTSelector.new()
	
	# Branch 1: IsNotHealthy -> FleeAction
	var flee_sequence = BTSequence.new()
	
	var inverter = BTInverter.new()
	inverter.child = IsHealthy.new()
	
	flee_sequence.children = [
		inverter,
		FleeAction.new()
	] as Array[BTNode]
	
	# Branch 2: PatrolUntilSpotted -> ChasePlayer -> AttackIfInRange
	var combat_sequence = BTSequence.new()
	combat_sequence.children = [
		PatrolUntilSpotted.new(),
		ChasePlayer.new(),
		AttackIfInRange.new()
	] as Array[BTNode]
	
	root.children = [
		flee_sequence,
		combat_sequence
	] as Array[BTNode]
	
	return root
