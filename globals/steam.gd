extends Node
class_name SteamBackend

## Steam backend: Steam lobbies for discovery, SteamMultiplayerPeer for the
## actual connection. The lobby owner hosts; everyone else connects to them.

signal lobby_created(error)
signal lobby_joined(error)
signal lobby_match_list_updated(lobbies: Array)
## The player accepted an invite or used "Join game" in the Steam overlay.
signal join_requested(lobby_id: int)

const MAX_MEMBERS: int = 10
const STEAM_RESULT_OK: int = 1
## Filters lobbies to this game. App ID 480 (Spacewar) is shared by every
## developer, so this only matters in development.
const LOBBY_APP_KEY: String = "template"

var current_lobby_id: int = 0

var _ready_ok: bool = false
var _peer: SteamMultiplayerPeer
var _joining := false


func is_ready() -> bool:
	return _ready_ok


func create_lobby() -> void:
	if not _require_ready(lobby_created):
		return
	leave_lobby()
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_MEMBERS)


func join_lobby(lobby_id: int) -> void:
	if not _require_ready(lobby_joined):
		return
	leave_lobby()
	_joining = true
	Steam.joinLobby(lobby_id)


func leave_lobby() -> void:
	_joining = false

	if current_lobby_id != 0:
		Steam.leaveLobby(current_lobby_id)
		current_lobby_id = 0

	if _peer:
		_peer.close()
		_peer = null

	# Restore the default offline peer. Setting `null` would make is_server()
	# return false and get_unique_id() error until a new peer is assigned.
	if multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func refresh_lobby_list() -> void:
	if not _ready_ok:
		return
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListStringFilter("_app_id", LOBBY_APP_KEY, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()


func _ready() -> void:
	# Only pump Steam callbacks once initialization succeeded.
	set_process(false)

	if not Steam:
		push_error(
			"Steam singleton not found. You need `SteamGodot SteamMultiplayerPeer` version of editor."
		)
		return

	if not _init_steam():
		push_error("Error: Failed to initialize Steam. Is Steam app running and logged in?")
		return

	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.join_requested.connect(_on_join_requested)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	set_process(true)
	_ready_ok = true


func _process(_delta: float) -> void:
	Steam.run_callbacks()


func _init_steam() -> bool:
	var result = Steam.steamInit()
	# Newer GodotSteam versions return a bool. Older ones return a status
	# Dictionary, which is always truthy, so check for a logged in user instead.
	if result is bool:
		return result
	return Steam.getSteamID() != 0


func _require_ready(result_signal: Signal) -> bool:
	if _ready_ok:
		return true
	result_signal.emit("Steam is not available. Is the Steam app running and logged in?")
	return false


func _on_lobby_created(lobby_connect: int, lobby_id: int) -> void:
	if lobby_connect != STEAM_RESULT_OK:
		lobby_created.emit("Failed to create lobby: %s" % lobby_connect)
		return

	current_lobby_id = lobby_id
	Steam.setLobbyJoinable(lobby_id, true)
	Steam.setLobbyData(lobby_id, "_app_id", LOBBY_APP_KEY)
	Steam.setLobbyData(lobby_id, "name", "Test Name")
	Steam.setLobbyData(lobby_id, "state", "waiting")

	_peer = SteamMultiplayerPeer.new()
	var err: Error = _peer.create_host(0)
	if err != OK:
		leave_lobby()
		lobby_created.emit("Failed to start hosting: %s" % error_string(err))
		return

	multiplayer.multiplayer_peer = _peer
	lobby_created.emit(null)


func _on_lobby_match_list(lobby_ids: Array) -> void:
	var list = lobby_ids.map(
		func(lobby_id: int):
			var lobby_name := Steam.getLobbyData(lobby_id, "name")
			var lobby_state := Steam.getLobbyData(lobby_id, "state")
			var lobby_num_members := Steam.getNumLobbyMembers(lobby_id)
			return {
				"id": lobby_id,
				"name": lobby_name,
				"state": lobby_state,
				"num_members": lobby_num_members
			}
	)
	lobby_match_list_updated.emit(list)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	# Steam also reports "joined" to the lobby creator. The host is already
	# set up in _on_lobby_created, so ignore it here.
	var owner_id: int = Steam.getLobbyOwner(lobby_id)
	if owner_id == Steam.getSteamID() or not _joining:
		return

	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		_joining = false
		push_error("Failed to join lobby: %s" % response)
		refresh_lobby_list()
		lobby_joined.emit(_join_fail_reason(response))
		return

	current_lobby_id = lobby_id
	_peer = SteamMultiplayerPeer.new()
	var err: Error = _peer.create_client(owner_id, 0)
	if err != OK:
		leave_lobby()
		lobby_joined.emit("Failed to connect to the host: %s" % error_string(err))
		return

	# lobby_joined is emitted once the connection to the host is up.
	multiplayer.multiplayer_peer = _peer


func _on_connected_to_server() -> void:
	if not _joining:
		return
	_joining = false
	lobby_joined.emit(null)


func _on_connection_failed() -> void:
	if not _joining:
		return
	leave_lobby()
	lobby_joined.emit("Could not connect to the host.")


func _on_join_requested(lobby_id: int, _friend_id: int) -> void:
	join_requested.emit(lobby_id)


func _join_fail_reason(response: int) -> String:
	var reasons := {
		Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: "This lobby no longer exists.",
		Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: "You don't have permission to join this lobby.",
		Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: "The lobby is now full.",
		Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: "Uh... something unexpected happened!",
		Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: "You are banned from this lobby.",
		Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: "You cannot join due to having a limited account.",
		Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: "This lobby is locked or disabled.",
		Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: "This lobby is community locked.",
		Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU:
		"A user in the lobby has blocked you from joining.",
		Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER:
		"A user you have blocked is in the lobby.",
	}
	return reasons.get(response, "Failed to join the lobby.")
