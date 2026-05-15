extends Node

const PORT = 9999

enum GameState {
	WAITING,
	COUNTDOWN,
	PLAYING,
	ENDING
}

var game_state = GameState.WAITING

var min_players = 2
var round_time = 30.0
var end_time = 5.0

var current_time = 0.0

@onready var status_label = $CanvasLayer/StatusLabel

@export var player_scene: PackedScene

var auto_host = false
var join_ip = ""

func get_player_count():
	var count = 0

	for child in get_children():
		if child is CharacterBody3D:
			count += 1

	return count

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

func _process(delta):

	update_ui()

	if !multiplayer.is_server():
		return

	match game_state:

		GameState.WAITING:
			if get_player_count() >= min_players:
				start_countdown()

		GameState.COUNTDOWN:
			current_time -= delta

			if current_time <= 0:
				start_round()

		GameState.PLAYING:
			current_time -= delta

			if current_time <= 0:
				end_round()

		GameState.ENDING:
			current_time -= delta

			if current_time <= 0:
				restart_round()
	
	if multiplayer.is_server():
		sync_game_state.rpc(game_state, current_time)

func start_round():

	game_state = GameState.PLAYING
	current_time = round_time

	print("ROUND STARTED")

func end_round():

	game_state = GameState.ENDING
	current_time = end_time

	print("ROUND ENDED")

func restart_round():

	game_state = GameState.WAITING

	print("WAITING FOR PLAYERS")

func update_ui():

	match game_state:

		GameState.WAITING:
			status_label.text = "Waiting for players..."

		GameState.COUNTDOWN:
			status_label.text = "Starting in: " + str(ceil(current_time))

		GameState.PLAYING:
			status_label.text = "Time Left: " + str(ceil(current_time))

		GameState.ENDING:
			status_label.text = "Round Over!"

func start_countdown():

	game_state = GameState.COUNTDOWN
	current_time = 3.0

@rpc("authority", "call_local")
func sync_game_state(new_state, new_time):

	game_state = new_state
	current_time = new_time
