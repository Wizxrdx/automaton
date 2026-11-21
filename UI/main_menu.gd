extends Control

@onready var level = $LevelInstance
@onready var volume_slider: HSlider = $VBoxContainer/VolumePanel/VolumeMargin/VolumeRow/VolumeSlider
@onready var volume_value: Label = $VBoxContainer/VolumePanel/VolumeMargin/VolumeRow/VolumeValue

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	volume_slider.set_value_no_signal(LevelManager.master_volume)
	volume_value.text = str(int(round(LevelManager.master_volume * 100.0))) + "%"

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

func _on_volume_slider_value_changed(value: float):
	LevelManager.set_master_volume(value)
	if volume_value:
		volume_value.text = str(int(round(value * 100.0))) + "%"
