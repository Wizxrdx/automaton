extends Node2D

@onready var item_sprite = $item # A Sprite2D child of this node
var held_item = null

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

func take_item() -> String:
	var item = held_item
	held_item = null
	_update_visuals()
	return item

func _update_visuals():
	if held_item and held_item in item_textures:
		item_sprite.texture = item_textures[held_item]
		item_sprite.visible = true
		# Position it on the robot's back
		item_sprite.position = Vector2(0, -5) 
	else:
		item_sprite.visible = false
