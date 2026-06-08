extends Node2D

@onready var synchronizer = $MultiplayerSynchronizer

func _enter_tree():
	# Set authority to the peer ID represented by the node's name
	var peer_id = name.to_int()
	set_multiplayer_authority(peer_id)
	print("[Player ", name, "] _enter_tree: authority set to ", peer_id)

func _ready():
	# Configure MultiplayerSynchronizer programmatically
	var config = SceneReplicationConfig.new()
	
	# Add position property to replicate ALWAYS
	var pos_path = NodePath(".:position")
	config.add_property(pos_path)
	config.property_set_spawn(pos_path, true)
	config.property_set_replication_mode(pos_path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	
	# Add name property to replicate ON_CHANGE
	var name_path = NodePath(".:name")
	config.add_property(name_path)
	config.property_set_spawn(name_path, true)
	config.property_set_replication_mode(name_path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	
	synchronizer.replication_config = config
	print("[Player ", name, "] _ready: replication config initialized. Authority is ", is_multiplayer_authority())

func _process(delta):
	if is_multiplayer_authority():
		# Simple movement over time to demonstrate synchronization
		var time = Time.get_ticks_msec() / 1000.0
		position = Vector2(cos(time) * 100.0, sin(time) * 100.0)
		# Print position occasionally (e.g., every 60 frames)
		if Engine.get_frames_drawn() % 60 == 0:
			print("[Player ", name, " (Authority)] Position updated locally to: ", position)
	else:
		# Print position occasionally to show it is synchronized on non-authoritative peers
		if Engine.get_frames_drawn() % 60 == 0:
			print("[Player ", name, " (Remote)] Position synchronized to: ", position)
