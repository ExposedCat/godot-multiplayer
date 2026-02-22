extends Control

@export var world_scene: PackedScene

func _on_host_pressed() -> void:
	get_tree().change_scene_to_packed(world_scene)
