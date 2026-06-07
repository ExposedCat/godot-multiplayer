class_name Cooldown
extends Resource

var cooldown_until_msec := 0
var duration_seconds := 0.0


func _init(cooldown_duration_seconds: float) -> void:
	duration_seconds = cooldown_duration_seconds


func fire() -> bool:
	var allowed := can_fire()
	if allowed:
		cooldown_until_msec = Time.get_ticks_msec() + int(duration_seconds * 1000.0)
	return allowed


func can_fire() -> bool:
	return Time.get_ticks_msec() >= cooldown_until_msec
