extends Control

@onready var ip_input = $VBoxContainer/IPInput

func _on_host_button_pressed():
	var scene = load("res://main.tscn").instantiate()

	scene.auto_host = true

	get_tree().root.add_child(scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = scene

func _on_join_button_pressed():
	var scene = load("res://main.tscn").instantiate()

	scene.join_ip = ip_input.text

	get_tree().root.add_child(scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = scene
