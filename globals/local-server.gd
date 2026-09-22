extends Node
class_name LocalBackend

## Dev mode backend: plain ENet, no lobby discovery. The lobby list always
## offers the local host; other machines are reached through `join_address`.

signal lobby_created(error)
signal lobby_joined(error)
signal lobby_match_list_updated(lobbies: Array)

const MAX_MEMBERS: int = 10
const SERVER_PORT: int = 2456
const DEFAULT_HOST: String = "127.0.0.1"
const DEVELOPMENT_LOBBY_ID: int = 1
const DEVELOPMENT_LOBBY_NAME: String = "Development Lobby"

var current_lobby_id: int = 0

var _peer: ENetMultiplayerPeer
var _joining := false


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)


func is_ready() -> bool:
	return true


func create_lobby() -> void:
	leave_lobby()

	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(SERVER_PORT, MAX_MEMBERS)
	if err != OK:
		_peer = null
		lobby_created.emit("Failed to create lobby: %s" % error_string(err))
		return

	multiplayer.multiplayer_peer = _peer
	current_lobby_id = DEVELOPMENT_LOBBY_ID
	lobby_created.emit(null)


func join_lobby(_lobby_id: int) -> void:
	join_address(DEFAULT_HOST)


## Accepts "host" or "host:port". An empty address means localhost.
func join_address(address: String) -> void:
	leave_lobby()

	var host := address.strip_edges()
	var port := SERVER_PORT
	if host.count(":") == 1:
		port = host.get_slice(":", 1).to_int()
		host = host.get_slice(":", 0)
	if host.is_empty():
		host = DEFAULT_HOST

	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(host, port)
	if err != OK:
		_peer = null
		lobby_joined.emit("Failed to connect to %s:%d: %s" % [host, port, error_string(err)])
		return

	_joining = true
	multiplayer.multiplayer_peer = _peer


func leave_lobby() -> void:
	_joining = false
	current_lobby_id = 0

	if _peer:
		_peer.close()
		_peer = null

	# Restore the default offline peer. Setting `null` would make is_server()
	# return false and get_unique_id() error until a new peer is assigned.
	if multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func refresh_lobby_list() -> void:
	var lobby := {
		"id": DEVELOPMENT_LOBBY_ID,
		"name": "%s (%s)" % [DEVELOPMENT_LOBBY_NAME, DEFAULT_HOST],
		"state": "unknown",
		"num_members": 0,
	}
	lobby_match_list_updated.emit([lobby])


func _on_connected_to_server() -> void:
	if not _joining:
		return
	_joining = false
	current_lobby_id = DEVELOPMENT_LOBBY_ID
	lobby_joined.emit(null)


func _on_connection_failed() -> void:
	if not _joining:
		return
	leave_lobby()
	lobby_joined.emit("Could not reach the host.")
