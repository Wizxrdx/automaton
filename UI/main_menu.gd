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
	# 1. Immediate UI Feedback
	$VBoxContainer.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	
	# 2. Start the "Pre-load" beat
	# We use this time to do the heavy 'Reparent' logic BEFORE the player sees it
	var root = get_tree().root
	var old_pos = level.global_position 
	remove_child(level)
	root.add_child(level)
	level.global_position = old_pos 
	
	# 3. Dramatic Pause 
	# This gives the browser 1 second to settle the new scene tree
	await get_tree().create_timer(1.0).timeout 

	# 4. The Switch
	# We've already moved the level, now we just turn on the "Game" part
	level.start_as_player()
	
	# 5. THE HTML5 FIX: Wait TWO frames
	# Frame 1: Godot registers the new StaticLevelCamera
	# Frame 2: The GPU clears the old Main Menu textures
	await get_tree().process_frame
	await get_tree().process_frame
	
	self.queue_free()

func _on_quit_button_pressed():
	pass
