extends Node

const PORT = 10567
const ADDRESS = "127.0.0.1"

@onready var players_container = $Players
@onready var multiplayer_spawner = $MultiplayerSpawner

var player_scene = preload("res://player.tscn")

func _ready():
	var args = OS.get_cmdline_args()
	var user_args = OS.get_cmdline_user_args()
	print("Command line args: ", args)
	print("Command line user args: ", user_args)
	
	var is_server = false
	var is_client = false
	
	for arg in args + user_args:
		if arg == "--server" or arg == "server":
			is_server = true
		elif arg == "--client" or arg == "client":
			is_client = true
			
	# Initialize spawner settings
	multiplayer_spawner.spawn_path = players_container.get_path()
	multiplayer_spawner.add_spawnable_scene("res://player.tscn")
	
	if is_server:
		start_server()
	elif is_client:
		start_client()
	else:
		print("Please specify --server or --client command-line argument.")

func start_server():
	print("Starting server on port ", PORT, "...")
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT)
	if err != OK:
		print("Failed to start server: ", err)
		return
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	print("Server successfully started and listening on port ", PORT)

func _on_peer_connected(id: int):
	print("Peer connected: ", id)
	# Check if player node already exists
	if players_container.has_node(str(id)):
		print("Player node already exists for peer ", id)
		return
	# Spawn player scene for the connected client
	var player = player_scene.instantiate()
	player.name = str(id)
	players_container.add_child(player)
	print("Spawned player node for peer ", id, " with name ", player.name)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	var player = players_container.get_node_or_null(str(id))
	if player:
		player.queue_free()
		print("Removed player node for peer ", id)

func start_client():
	print("Starting client and connecting to ", ADDRESS, ":", PORT, "...")
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ADDRESS, PORT)
	if err != OK:
		print("Failed to start client: ", err)
		return
	
	multiplayer.multiplayer_peer = peer
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connected_to_server():
	print("Connected to server successfully!")

func _on_connection_failed():
	print("Connection to server failed.")

func _on_server_disconnected():
	print("Disconnected from server.")
