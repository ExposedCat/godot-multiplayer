extends RigidBase

func _init():
	super (1.0)

func do_interact(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	if cooldown.fire():
		print("Interacting with cube", payload)
		position.y += 5
