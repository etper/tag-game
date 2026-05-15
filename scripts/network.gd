extends Node

const PORT = 9999

enum GameState {
	WAITING,
	COUNTDOWN,
	PLAYING,
	ENDING
}

var player_scores = {
	
}

var game_state = GameState.WAITING

@onready var tag_sound = $TagSound

@onready var scoreboard_label = $CanvasLayer/ScoreboardLabel

@onready var pressure_bar = $CanvasLayer/PressureBar

@export var burst_scene: PackedScene

var min_players = 2
var round_time = 30.0
var end_time = 5.0

var current_time = 0.0

@onready var status_label = $CanvasLayer/StatusLabel

var it_player_id = -1
var last_tag_time = 0.0
var tag_cooldown = 1.0

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
	
	player_scores[id] = 0

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
			
			if it_player_id != -1:
				player_scores[it_player_id] += delta
			
			check_tagging()
			check_fallen_players()

			if current_time <= 0:
				end_round()

		GameState.ENDING:
			current_time -= delta

			if current_time <= 0:
				restart_round()
	
	if multiplayer.is_server():
		sync_game_state.rpc(game_state, current_time)

func teleport_players():

	var spawn_points = $SpawnPoints.get_children()

	var used_spawns = []

	for child in get_children():

		if child is CharacterBody3D:

			var available_spawns = []

			for spawn in spawn_points:
				if !used_spawns.has(spawn):
					available_spawns.append(spawn)

			if available_spawns.size() == 0:
				return

			var random_spawn = available_spawns.pick_random()

			used_spawns.append(random_spawn)

			child.force_teleport.rpc(random_spawn.global_position)

func start_round():

	teleport_players()

	game_state = GameState.PLAYING
	current_time = round_time

	var players = []

	for child in get_children():
		if child is CharacterBody3D:
			players.append(int(child.name))

	if players.size() > 0:
		it_player_id = players.pick_random()
		update_it_player.rpc(it_player_id)

	print("ROUND STARTED")

func end_round():

	var losing_player = -1
	var highest_score = -1.0
	
	for id in player_scores:
		
		if player_scores[id] > highest_score:
			
			highest_score = player_scores[id]
			losing_player = id

	game_state = GameState.ENDING
	current_time = end_time

	print("ROUND ENDED")
	print("LOSER: ", losing_player)

func restart_round():

	game_state = GameState.WAITING

	print("OCZEKIWANIE NA GRACZY")

func update_ui():

	match game_state:

		GameState.WAITING:
			status_label.text = "Oczekiwanie na graczy..."

		GameState.COUNTDOWN:
			status_label.text = "Start za: " + str(ceil(current_time))

		GameState.PLAYING:
			status_label.text = "Pozostały czas: " + str(ceil(current_time))

		GameState.ENDING:
			status_label.text = "Koniec rundy!"

	# SCOREBOARD UI
	var sorted_players = player_scores.keys()

	sorted_players.sort_custom(func(a, b):
		return player_scores[a] > player_scores[b]
	)

	var score_text = ""

	for id in sorted_players:

		var line = "Player " + str(id)

		if id == it_player_id:
			line += " [IT]"

		if id == sorted_players[0]:
			line += " ⚠"

		line += " : " + str(snapped(player_scores[id], 0.1))

		score_text += line + "\n"

	scoreboard_label.text = score_text
	
	pressure_bar.value = get_local_pressure_ratio() * 100.0

func start_countdown():

	game_state = GameState.COUNTDOWN
	current_time = 3.0

@rpc("authority", "call_local")
func sync_game_state(new_state, new_time):

	game_state = new_state
	current_time = new_time

@rpc("authority", "call_local")
func update_it_player(new_it_id):

	it_player_id = new_it_id

	for child in get_children():

		if child is CharacterBody3D:

			child.set_is_it(int(child.name) == it_player_id)

func check_tagging():

	if Time.get_ticks_msec() / 1000.0 - last_tag_time < tag_cooldown:
		return

	var it_player = get_node_or_null(str(it_player_id))

	if it_player == null:
		return

	var DANGER_RADIUS = 10.0

	for child in get_children():

		if child is CharacterBody3D:

			if child == it_player:
				continue

			var distance = it_player.global_position.distance_to(
				child.global_position
			)

			# danger feedback
			if distance < DANGER_RADIUS:

				var danger_strength = 1.0 - (
					distance / DANGER_RADIUS
				)

				child.set_danger_level.rpc(
					danger_strength
				)

			else:

				child.set_danger_level.rpc(0.0)

			# actual tag
			if distance < 1.3:

				it_player_id = int(child.name)

				last_tag_time = Time.get_ticks_msec() / 1000.0

				update_it_player.rpc(it_player_id)

				print("TAGGED: ", it_player_id)

				hit_pause.rpc()

				tag_sound.pitch_scale = randf_range(0.95, 1.05)
				tag_sound.play()

				it_player.add_screenshake.rpc(0.12)
				child.add_screenshake.rpc(0.18)

				spawn_tag_burst.rpc(
					(it_player.global_position + child.global_position) * 0.5
				)

				child.apply_speed_boost.rpc()

				return

func check_fallen_players():

	var spawn_points = $SpawnPoints.get_children()

	for child in get_children():

		if child is CharacterBody3D:

			# fell under map
			if child.global_position.y < 0:

				var random_spawn = spawn_points.pick_random()

				child.global_position = random_spawn.global_position

@rpc("call_local")
func hit_pause():

	Engine.time_scale = 0.05

	await get_tree().create_timer(0.05, true, false, true).timeout

	Engine.time_scale = 1.0

@rpc("call_local")
func spawn_tag_burst(pos):

	var burst = burst_scene.instantiate()

	add_child(burst)

	burst.global_position = pos + Vector3.UP

func get_local_pressure_ratio():

	var local_id = multiplayer.get_unique_id()

	if !player_scores.has(local_id):
		return 0.0

	var highest = 0.0

	for id in player_scores:
		highest = max(highest, player_scores[id])

	if highest <= 0:
		return 0.0

	return player_scores[local_id] / highest
