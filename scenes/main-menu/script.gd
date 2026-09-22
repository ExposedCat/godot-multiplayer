extends Control

@export var lobbies: VBoxContainer
@export var refresh_timer: Timer
@export var host_button: Button
@export var status_label: Label
@export var direct_connect: Control
@export var address_input: LineEdit
@export var join_address_button: Button

## True while a host/join request is in flight, so repeated clicks can't
## start several lobbies or connections at once.
var _busy := false


func _ready() -> void:
	NetworkManager.lobby_match_list_updated.connect(_set_rooms)
	NetworkManager.lobby_created.connect(_on_lobby_result)
	NetworkManager.lobby_joined.connect(_on_lobby_result)
	refresh_timer.timeout.connect(NetworkManager.refresh_lobby_list)
	join_address_button.pressed.connect(_on_join_address_pressed)
	address_input.text_submitted.connect(func(_text): _on_join_address_pressed())

	direct_connect.visible = NetworkManager.is_dev_mode()
	_set_status(NetworkManager.consume_last_error())
	NetworkManager.refresh_lobby_list()


func _on_host_pressed() -> void:
	if _begin_request("Creating lobby..."):
		NetworkManager.create_lobby()


func _on_join_room_pressed(room: Dictionary) -> void:
	if _begin_request("Joining %s..." % room.name):
		NetworkManager.join_lobby(room.id)


func _on_join_address_pressed() -> void:
	if _begin_request("Connecting to %s..." % address_input.text):
		NetworkManager.join_address(address_input.text)


## On success SceneManager switches to the world; only failures land here.
func _on_lobby_result(error) -> void:
	if error == null:
		return
	push_error(error)
	_set_busy(false)
	_set_status(str(error))


func _begin_request(message: String) -> bool:
	if _busy:
		return false
	_set_busy(true)
	_set_status(message)
	return true


func _set_busy(busy: bool) -> void:
	_busy = busy
	host_button.disabled = busy
	join_address_button.disabled = busy
	for child in lobbies.get_children():
		if child is Button:
			child.disabled = busy


func _set_status(message: String) -> void:
	status_label.text = message
	status_label.visible = not message.is_empty()


func _set_rooms(rooms: Array) -> void:
	for child in lobbies.get_children():
		lobbies.remove_child(child)
		child.queue_free()

	if rooms.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No lobbies found."
		lobbies.add_child(empty_label)
		return

	for room in rooms:
		var button := Button.new()
		button.text = room.name
		if room.num_members > 0:
			button.text += " (%s)" % room.num_members
		button.disabled = _busy
		button.pressed.connect(_on_join_room_pressed.bind(room))
		lobbies.add_child(button)
