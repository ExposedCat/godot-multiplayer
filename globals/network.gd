extends Node

signal player_joined(peer_id: int)
signal player_left(peer_id: int)

const PORT := 2456
var peer: ENetMultiplayerPeer


func host_game(max_clients := 16):
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, max_clients)
	var mp = get_tree().get_multiplayer()
	mp.multiplayer_peer = peer


func join_game(host: String):
	peer = ENetMultiplayerPeer.new()
	peer.create_client(host, PORT)
	var mp = get_tree().get_multiplayer()
	mp.multiplayer_peer = peer


func _ready():
	var mp = get_tree().get_multiplayer()
	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(id: int):
	player_joined.emit(id)


func _on_peer_disconnected(id: int):
	player_left.emit(id)


func is_host() -> bool:
	return get_tree().get_multiplayer().is_server()
