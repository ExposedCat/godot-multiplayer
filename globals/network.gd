extends Node

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal lobby_created(error)
signal lobby_joined(error)
signal lobby_match_list_updated(lobbies: Array)
## Emitted when an active session ends. `reason` is empty when the local
## player left on purpose, otherwise it describes what went wrong.
signal session_ended(reason: String)

var _backend: Node
var _is_dev_mode := false
var _in_session := false
var _last_error := ""


func _ready():
	_setup_backend()

	var mp := get_tree().get_multiplayer()
	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)
	mp.server_disconnected.connect(_on_server_disconnected)

	_check_command_line.call_deferred()


func _on_peer_connected(id: int):
	player_joined.emit(id)


func _on_peer_disconnected(id: int):
	player_left.emit(id)


func is_host() -> bool:
	return get_tree().get_multiplayer().is_server()


func is_dev_mode() -> bool:
	return _is_dev_mode


func is_in_session() -> bool:
	return _in_session


func create_lobby() -> void:
	leave_lobby()
	_backend.call("create_lobby")


func join_lobby(lobby_id: int) -> void:
	leave_lobby()
	_backend.call("join_lobby", lobby_id)


## Dev mode only: connect straight to a host by IP or hostname ("host" or "host:port").
func join_address(address: String) -> void:
	if not _is_dev_mode:
		push_error("Direct connect is only available in dev mode.")
		return
	leave_lobby()
	_backend.call("join_address", address)


func leave_lobby() -> void:
	_backend.call("leave_lobby")
	_end_session("")


func refresh_lobby_list() -> void:
	_backend.call("refresh_lobby_list")


func is_ready() -> bool:
	return _backend.call("is_ready")


## Returns the reason the last session ended (if any) and clears it, so a
## freshly loaded menu can show it once.
func consume_last_error() -> String:
	var error := _last_error
	_last_error = ""
	return error


func _setup_backend() -> void:
	_is_dev_mode = _cmdline_args().has("--dev")
	_backend = LocalBackend.new() if _is_dev_mode else SteamBackend.new()

	_backend.lobby_created.connect(_on_backend_lobby_created)
	_backend.lobby_joined.connect(_on_backend_lobby_joined)
	_backend.lobby_match_list_updated.connect(_on_backend_lobby_match_list_updated)
	if _backend.has_signal("join_requested"):
		_backend.join_requested.connect(join_lobby)

	add_child(_backend)


## Engine-level args plus user args passed after `--`, so both
## `godot --dev` and `godot -- --dev` work.
func _cmdline_args() -> PackedStringArray:
	return OS.get_cmdline_args() + OS.get_cmdline_user_args()


## Steam launches the game with `+connect_lobby <id>` when joining through
## a friend or an invite while the game isn't running.
func _check_command_line() -> void:
	var args := _cmdline_args()
	var index := args.find("+connect_lobby")
	if index == -1 or index + 1 >= args.size():
		return

	var lobby_id := args[index + 1].to_int()
	if lobby_id <= 0:
		return

	print_debug("Command line lobby ID: %s" % lobby_id)
	join_lobby(lobby_id)


func _end_session(reason: String) -> void:
	if not _in_session:
		return
	_in_session = false
	_last_error = reason
	session_ended.emit(reason)


func _on_server_disconnected() -> void:
	_backend.call("leave_lobby")
	_end_session("Disconnected from the host.")


func _on_backend_lobby_created(error) -> void:
	_in_session = error == null
	lobby_created.emit(error)


func _on_backend_lobby_joined(error) -> void:
	_in_session = error == null
	lobby_joined.emit(error)


func _on_backend_lobby_match_list_updated(lobbies: Array) -> void:
	lobby_match_list_updated.emit(lobbies)
