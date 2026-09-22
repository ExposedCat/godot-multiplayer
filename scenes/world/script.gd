extends Node3D

var player_scene = preload("res://scenes/player/scene.tscn")

@export var player_container: Node3D
@export var player_spawner: MultiplayerSpawner

@onready var playerSpawner = Spawner.new(player_container, player_scene, player_spawner)


func _ready() -> void:
	playerSpawner.run()


func _unhandled_input(event: InputEvent) -> void:
	# Escape leaves the session; SceneManager then returns to the menu.
	if event.is_action_pressed("ui_cancel"):
		NetworkManager.leave_lobby()
