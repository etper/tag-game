extends Node

const PORT = 9999

@export var player_scene: PackedScene

var auto_host = false
var join_ip = ""

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_connected_ok)

	if auto_host:
		host_game()
	elif join_ip != "":
		join_game(join_ip)

func host_game():
	var peer = ENetMultiplayerPeer.new()

	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer

	print("Hosting")

	_spawn_player.rpc(multiplayer.get_unique_id())

func join_game(ip):
	var peer = ENetMultiplayerPeer.new()

	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer

	print("Joining")

func _connected_ok():
	print("Connected to server")

func _on_peer_connected(id):
	print("Peer connected: ", id)

	if multiplayer.is_server():

		# spawn new player everywhere
		_spawn_player.rpc(id)

		# tell new player about existing players
		for player in get_children():

			if player is CharacterBody3D:

				var existing_id = int(player.name)

				_spawn_player.rpc_id(id, existing_id)

@rpc("any_peer", "call_local")
func _spawn_player(id):
	if has_node(str(id)):
		return

	var player = player_scene.instantiate()

	player.name = str(id)

	player.set_multiplayer_authority(id)

	add_child(player)
