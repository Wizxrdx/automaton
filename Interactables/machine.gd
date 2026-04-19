extends StaticBody2D

var robot_scene = preload("res://Units/Friendly/robot.tscn")
var highlighted := false

func interact(player_ref):
	var robot = robot_scene.instantiate()
	# Set player before adding to tree so _ready() has it
	robot.player = player_ref
	robot.global_position = global_position
	get_parent().add_child(robot)
	queue_free()

func set_highlight(state: bool):
	highlighted = state
	$Sprite2D.modulate = Color(1, 1, 0.6) if highlighted else Color(1, 1, 1)
