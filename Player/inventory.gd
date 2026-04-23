extends Node2D

@onready var item_sprite = $item
var held_item = null

# The inventory only needs to know what things LOOK like in the UI
var item_textures = {
	"battery": preload("res://Items/Types/battery.png"),
	"scrap": preload("res://Items/Types/scrap.png"),
	"tires": preload("res://Items/Types/tires.png")
}

func _ready():
	item_sprite.visible = false

func has_item() -> bool:
	return held_item != null

func add_item(item_type: String):
	held_item = item_type
	_update_visuals()

func consume_item():
	held_item = null
	_update_visuals()

func drop_and_spawn(spawn_pos: Vector2) -> Node2D:
	if not held_item: 
		return null
	
	# Tell the Global Manager to do the heavy lifting
	var spawned_item = ItemManager.spawn_item(held_item, spawn_pos)
	
	if spawned_item:
		# Temporarily disable pickup so the player doesn't instantly grab it again
		spawned_item.set_deferred("monitoring", false)
		_prevent_immediate_pickup(spawned_item)
	
	held_item = null
	_update_visuals()
	
	return spawned_item

func _prevent_immediate_pickup(item_node: Node2D):
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(item_node):
		item_node.set_deferred("monitoring", true)

func _update_visuals():
	if held_item and item_textures.has(held_item):
		item_sprite.texture = item_textures[held_item]
		item_sprite.visible = true
	else:
		item_sprite.visible = false
