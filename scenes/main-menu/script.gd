extends Control

@export var world_scene: PackedScene


func _on_host_pressed() -> void:
	NetworkManager.host_game()
	SceneManager.change_state(SceneManager.State.WORLD, false)


func _on_join_pressed() -> void:
	NetworkManager.join_game("localhost")
	SceneManager.change_state(SceneManager.State.WORLD, false)
