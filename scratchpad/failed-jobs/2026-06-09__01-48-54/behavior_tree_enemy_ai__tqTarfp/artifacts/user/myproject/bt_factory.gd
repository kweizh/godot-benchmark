class_name BTFactory
extends RefCounted

static func build_enemy_tree() -> BTNode:
    var is_healthy = IsHealthy.new()
    var inverter = BTInverter.new(is_healthy)
    var flee = FleeAction.new()
    var seq1 = BTSequence.new([inverter, flee])
    
    var patrol = PatrolUntilSpotted.new()
    var chase = ChasePlayer.new()
    var attack = AttackIfInRange.new()
    var seq2 = BTSequence.new([patrol, chase, attack])
    
    var root = BTSelector.new([seq1, seq2])
    return root
