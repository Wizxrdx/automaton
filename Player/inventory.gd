extends Node2D

@onready var item_sprite = $item
var held_item = null

var item_scenes = {
	"battery": preload("res://Items/Types/battery.tscn"),
	"scrap": preload("res://Items/Types/scrap.tscn"),
	"tires": preload("res://Items/Types/tires.tscn")
}

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

func drop_and_spawn(spawn_pos: Vector2):
	if not held_item: return
	var item_to_spawn = held_item
	held_item = null
	_update_visuals()
	
	var scene_to_instance = item_scenes.get(item_to_spawn)
	if not scene_to_instance: return null
	var new_item = scene_to_instance.instantiate()
	new_item.global_position = spawn_pos
	get_tree().current_scene.add_child(new_item)
	
	new_item.set_deferred("monitoring", false)
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(new_item):
		new_item.set_deferred("monitoring", true)
		return new_item
	return null

func _update_visuals():
	if held_item and held_item in item_textures:
		item_sprite.texture = item_textures[held_item]
		item_sprite.visible = true
	else:
		item_sprite.visible = false
