extends Area2D

@export var item_type: String = "scrap"
@onready var sprite = $Sprite2D

func get_item_type():
	return item_type

func set_highlight(state: bool):
	if sprite:
		sprite.modulate = Color(1, 1, 0.6) if state else Color(1, 1, 1)
