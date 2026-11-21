extends Area2D

@export var item_type: String = "scrap"
@export var cooldown_time: float = 0.2

@onready var sprite = $Sprite2D

var is_held: bool = false
var on_cooldown: bool = false

func _ready():
	add_to_group("item")
	# Ensure Pickable is on so mouse signals work
	input_pickable = true
	# Connect mouse signals only if not already connected in the scene
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func get_item_type() -> String:
	return item_type

func set_highlight(state: bool):
	sprite.modulate = Color(1.5, 1.5, 1.1) if state else Color(1, 1, 1)

func _on_mouse_entered():
	if can_be_picked_up():
		set_highlight(true)

func _on_mouse_exited():
	set_highlight(false)

func pick_up():
	is_held = true
	on_cooldown = false 
	set_highlight(false) # Turn off highlight when grabbed

func drop_to_ground():
	is_held = false
	_start_cooldown()

func _start_cooldown():
	on_cooldown = true
	await get_tree().create_timer(cooldown_time).timeout
	on_cooldown = false

func can_be_picked_up() -> bool:
	return not is_held and not on_cooldown
