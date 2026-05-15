extends Node

const PORT = 9999
@export var player_scene: PackedScene

var auto_host = false
var join_ip = ""

func host_game():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer

	print("Hosting game")

	_spawn_player(multiplayer.get_unique_id())

func join_game(ip):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer

	print("Joining game")

func _ready():
	multiplayer.peer_connected.connect(_player_connected)

	if auto_host:
		host_game()

	elif join_ip != "":
		join_game(join_ip)

func _player_connected(id):
	if multiplayer.is_server():
		_spawn_player(id)

func _spawn_player(id):
	var player = player_scene.instantiate()

	player.name = str(id)

	add_child(player)

	player.set_multiplayer_authority(id)
