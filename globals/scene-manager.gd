extends Node

var scenes := {
	State.MENU: preload("res://scenes/main-menu/scene.tscn"),
	State.WORLD: preload("res://scenes/world/scene.tscn")
}

enum State { MENU, WORLD }

signal state_changed(from: State, to: State)

var epoch := 0
var state := State.MENU


func _ready():
	set_multiplayer_authority(1)

	# Scene flow follows the network session: enter the world once a lobby is
	# ready (from the menu, a command line join or a Steam invite), and return
	# to the menu when the session ends.
	NetworkManager.lobby_created.connect(_on_lobby_ready)
	NetworkManager.lobby_joined.connect(_on_lobby_ready)
	NetworkManager.session_ended.connect(_on_session_ended)


func _on_lobby_ready(error) -> void:
	if error == null and state != State.WORLD:
		change_state(State.WORLD, false)


func _on_session_ended(_reason: String) -> void:
	if state != State.MENU:
		change_state(State.MENU, false)


func change_state(to: State, broadcast: bool):
	if broadcast and multiplayer.is_server():
		epoch += 1
		broadcast_state_change.rpc(to, epoch)
	else:
		_do_change_state(to, epoch)


@rpc("authority", "call_local", "reliable")
func broadcast_state_change(to: State, send_epoch: int):
	_do_change_state(to, send_epoch)


func _do_change_state(to: State, send_epoch: int):
	if epoch > send_epoch:
		return
	epoch = send_epoch
	var from = state
	state = to
	state_changed.emit(from, state)
	get_tree().call_deferred("change_scene_to_packed", scenes[state])
