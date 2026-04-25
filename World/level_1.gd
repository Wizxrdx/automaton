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

func _input(event):
	if event.is_action_pressed("ui_cancel"): # This is the "Esc" key by default
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func start_as_player():
	# 1. Position and Swap
	player.global_position = cleaner.global_position
	
	# THE CLEAN KILL: Delete the cleaner so its logic stops forever
	cleaner.queue_free()
	
	player.show()
	# Stop any inherited momentum
	player.velocity = Vector2.ZERO

	var static_cam = get_node_or_null("StaticLevelCamera")
	if static_cam:
		# Wait for the Menu/Cleaner to be fully cleared from the tree
		await get_tree().process_frame 
		static_cam.make_current()
		print("Camera Status: Static Level Camera is now the Boss.")
	
	# 3. Enable controls
	player.set_physics_process(true)
	player.set_process_input(true)
	
	# Optional: If you want it invisible too, use:
	# Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
