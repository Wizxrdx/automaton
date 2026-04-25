extends Node2D

@onready var player = $Player
@onready var spawn = $SpawnPoint
@onready var cleaner = $Cleaner

@export var is_menu_background := false

func _ready():
	# If we are in the menu, we wait.
	if is_menu_background:
		setup_menu_mode()
	else:
		# If we are playing the level normally (e.g. testing the scene)
		start_level_normally()

func setup_menu_mode():
	player.hide()
	player.set_physics_process(false)
	player.set_process_input(false)

func start_level_normally():
	player.show()
	player.global_position = spawn.global_position
	player.set_physics_process(true)
	player.set_process_input(true)
	if cleaner:
		cleaner.hide() # Hide the NPC because the player is now here

func start_as_player():
	# 1. Position the player where the cleaner was
	player.global_position = cleaner.global_position
	
	# 2. Character swap
	cleaner.hide()
	player.show()
	
	# 3. ENABLE PLAYER CAMERA
	# This tells Godot to stop using the Menu Camera and start using the Player's
	var player_camera = player.get_node_or_null("Camera2D")
	if player_camera:
		player_camera.make_current() 
	
	# 4. Enable controls
	player.set_physics_process(true)
	player.set_process_input(true)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)	
