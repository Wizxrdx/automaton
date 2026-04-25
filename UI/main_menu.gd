extends Control

@onready var level = $LevelInstance

func _ready():
	# Force the level into background mode
	level.is_menu_background = true
	level.setup_menu_mode()
	
	# Ensure the Menu's own camera is the one being used
	$Camera2D.make_current() 
	
	# Center the level instance to (0,0) or whatever your camera is looking at
	level.position = Vector2.ZERO 
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_start_button_pressed():
	$VBoxContainer.visible = false
	
	# Simulate the cleaner 'waking up'
	await get_tree().create_timer(1.0).timeout 
	
	# The seamless handoff
	level.start_as_player()
	
	# Clean up the menu
	self.queue_free()
