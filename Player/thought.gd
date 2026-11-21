extends Node2D

@onready var icon = $icon
@onready var background = $background
@onready var swap = $swap

var textures = {
	"battery": preload("res://UI/battery_ui.png"),
	"scrap": preload("res://UI/scrap_ui.png"),
	"tires": preload("res://UI/tires_ui.png")
}

var current_item_type: String = ""
var current_is_replace: bool = false
var active_tween: Tween = null

func _ready() -> void:
	self.visible = false
	swap.visible = false

# Added is_replace and force_pop arguments
func update_thought(item_type: String, is_replace: bool = false, force_pop: bool = false):
	if item_type in textures:
		if self.visible and current_item_type == item_type and current_is_replace == is_replace and not force_pop:
			return
		current_item_type = item_type
		current_is_replace = is_replace
		icon.texture = textures[item_type]
		swap.visible = is_replace # Toggle the swap icon based on state
		
		self.visible = true
		self.scale = Vector2(0.5, 0.5)
		
		if active_tween and active_tween.is_valid():
			active_tween.kill()
		active_tween = create_tween()
		active_tween.tween_property(self, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_BACK)
	else:
		hide_thought()

func hide_thought():
	self.visible = false
	current_item_type = ""
	current_is_replace = false
