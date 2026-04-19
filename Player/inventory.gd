extends Node2D

@onready var item_sprite = $item
var ItemScene = preload("res://Items/item.tscn")

var held_item = null
var item_textures = {
	"battery": preload("res://Items/battery.png"),
	"scrap": preload("res://Items/scrap.png")
}

func _ready():
	item_sprite.visible = false

func has_item() -> bool:
	return held_item != null

func add_item(item_type: String):
	held_item = item_type
	_update_visuals()

# This handles the logic for dropping or swapping
func drop_and_spawn(spawn_pos: Vector2):
	if not held_item: return
	
	var item_to_spawn = held_item
	held_item = null
	_update_visuals()
	
	var new_item = ItemScene.instantiate()
	new_item.item_type = item_to_spawn
	new_item.global_position = spawn_pos
	
	get_tree().current_scene.add_child(new_item)
	
	# Safety delay so you don't instantly re-pickup
	new_item.set_deferred("monitoring", false)
	await get_tree().create_timer(0.2).timeout
	
	if is_instance_valid(new_item):
		new_item.monitoring = true
		return new_item # Returns the item so player can update bubble if standing over it
	return null

func consume_item():
	held_item = null
	_update_visuals()

func _update_visuals():
	if held_item and held_item in item_textures:
		item_sprite.texture = item_textures[held_item]
		item_sprite.visible = true
	else:
		item_sprite.visible = false
