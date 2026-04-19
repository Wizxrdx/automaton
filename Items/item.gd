extends Area2D

@export var item_type: String = "scrap"
@onready var sprite = $Sprite2D

var textures = {
	"battery": preload("res://Items/battery.png"),
	"scrap": preload("res://Items/scrap.png")
}

func _ready():
	update_visual()

func update_visual():
	if item_type in textures:
		sprite.texture = textures[item_type]

func get_item_type():
	return item_type

func set_highlight(state: bool):
	if sprite:
		sprite.modulate = Color(1, 1, 0.6) if state else Color(1, 1, 1)
