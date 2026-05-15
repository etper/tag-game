extends Node

const PORT = 9999
@export var player_scene: PackedScene

func host_game():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer

	print("Hosting game")

func join_game(ip):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer

	print("Joining game")

func _ready():
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.connected_to_server.connect(_connected_ok)

	if multiplayer.is_server():
		_spawn_player(multiplayer.get_unique_id())

func _connected_ok():
	_spawn_player(multiplayer.get_unique_id())

func _player_connected(id):
	if multiplayer.is_server():
		_spawn_player(id)

func _spawn_player(id):
	var player = player_scene.instantiate()

	player.name = str(id)

	add_child(player)

	player.set_multiplayer_authority(id)
