extends Node2D

@onready var icon = $icon
@onready var background = $background
@onready var swap = $swap

var textures = {
	"battery": preload("res://UI/battery_ui.png"),
	"scrap": preload("res://UI/scrap_ui.png"),
	"tires": preload("res://UI/tires_ui.png")
}

func _ready() -> void:
	self.visible = false
	swap.visible = false

# Added is_replace argument
func update_thought(item_type: String, is_replace: bool = false):
	if item_type in textures:
		icon.texture = textures[item_type]
		swap.visible = is_replace # Toggle the swap icon based on state
		
		self.visible = true
		self.scale = Vector2(0.5, 0.5)
		
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_BACK)
	else:
		hide_thought()

func hide_thought():
	self.visible = false
