extends Control

@onready var level = $LevelInstance

func _ready():
	# Force the level into background mode
	level.is_menu_background = true
	
	# Check if the function exists before calling to avoid crashes
	if level.has_method("setup_menu_mode"):
		level.setup_menu_mode()
	
	# Ensure the Menu's own camera is the one being used
	$StaticLevelCamera.make_current() 
	
	# Center the level instance
	level.position = Vector2.ZERO

func _on_start_button_pressed():
	$VBoxContainer.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	
	await get_tree().create_timer(1.0).timeout
	
	# REPARENT
	var root = get_tree().root
	var old_pos = level.global_position 
	remove_child(level)
	root.add_child(level)
	level.global_position = old_pos 

	level.start_as_player()
	
	# Wait one frame so Godot can register the new camera
	await get_tree().process_frame
	
	# Now it is safe to kill the menu (and its camera)
	self.queue_free()

func _on_quit_button_pressed():
	pass
