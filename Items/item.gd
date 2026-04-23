extends Area2D

@export var item_type: String = "scrap"
@export var cooldown_time: float = 30.0

@onready var sprite = $Sprite2D

var is_held: bool = false
var on_cooldown: bool = false

func _ready():
	add_to_group("item")

func get_item_type() -> String:
	return item_type

func set_highlight(state: bool):
	if sprite:
		sprite.modulate = Color(1, 1, 0.6) if state else Color(1, 1, 1)

# Call this when the item is picked up (by player OR robot)
func pick_up():
	is_held = true
	on_cooldown = false # Cancel any active cooldowns when grabbed

# Called by ItemManager.gd when spawned into the world
func drop_to_ground():
	is_held = false
	_start_cooldown()

# Internal timer function
func _start_cooldown():
	on_cooldown = true
	await get_tree().create_timer(cooldown_time).timeout
	on_cooldown = false

# The robotic arm checks this function before setting it as a target
func can_be_picked_up() -> bool:
	return not is_held and not on_cooldown
