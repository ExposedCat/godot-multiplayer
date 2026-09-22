extends RigidBase

## Upward speed (m/s) given to the cube when interacted with.
const LIFT_SPEED := 6.0


func _init():
	super(1.0)


func do_interact(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	if cooldown.fire():
		print("Interacting with cube", payload)
		body.apply_central_impulse(Vector3.UP * body.mass * LIFT_SPEED)
