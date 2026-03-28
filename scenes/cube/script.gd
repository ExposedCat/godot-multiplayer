extends RigidBody3D

var cooldown = Cooldown.new(1000)

func interact():
	if cooldown.fire():
		position.y += 1

func _process(_delta: float) -> void:
	print(position.y)