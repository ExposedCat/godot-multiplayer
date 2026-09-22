class_name InteractableBase extends Node3D

## Max distance in meters between the requesting player and this object,
## checked on the server. 0 disables the check.
@export var interaction_range := 2.0

var cooldown: Cooldown


func _init(cooldown_duration_seconds: float = 0.0):
	cooldown = Cooldown.new(cooldown_duration_seconds)


func do_interact(_payload: Dictionary) -> void:
	pass


## Server-side check run before an interaction is accepted. Requests come from
## clients, so don't trust them: override this to add game rules and call
## super() to keep the range check.
func can_interact(caller: Node3D, _payload: Dictionary) -> bool:
	if caller == null:
		return false
	if interaction_range <= 0.0:
		return true
	return caller.global_position.distance_to(global_position) <= interaction_range


func interact(payload: Dictionary = {}) -> void:
	rpc_id(1, "_interact_request", payload)


@rpc("any_peer", "call_local", "reliable")
func _interact_request(payload: Dictionary = {}) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not can_interact(_resolve_sender_node(sender_id), payload):
		return

	var authoritative_payload := _build_authoritative_payload(payload, sender_id)
	rpc("_execute_interaction", authoritative_payload)


@rpc("authority", "call_local", "reliable")
func _execute_interaction(payload: Dictionary) -> void:
	var local_payload := payload.duplicate(true)
	local_payload["caller"] = _resolve_sender_node(int(local_payload.get("peer_id", 0)))
	do_interact(local_payload)


func _build_authoritative_payload(payload: Dictionary, sender_id: int) -> Dictionary:
	var out := payload.duplicate(true)
	out["peer_id"] = sender_id
	return out


func _resolve_sender_node(sender_id: int) -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("player")
	var index = players.find_custom(func(node): return node.player_id == sender_id)
	return null if index == -1 else players[index]
