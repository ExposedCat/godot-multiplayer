class_name RigidBase extends InteractableBase

## The RigidBody3D this script is attached to. The script extends Node3D
## (through InteractableBase), so this gives typed access to the body.
@onready var body := self as Node as RigidBody3D


func _init(cooldown_duration_seconds: float = 0.0):
	super(cooldown_duration_seconds)


## Subclasses overriding _ready must call super() to keep this.
func _ready() -> void:
	# The server simulates the body. Clients only show the synced transform,
	# so their copy must not run its own physics and drift from the server.
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze = not multiplayer.is_server()
