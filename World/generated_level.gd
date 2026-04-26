extends Node2D

@onready var player = $Player
@onready var spawn = $SpawnPoint

func _ready():
	# 1. Move player to spawn
	player.global_position = spawn.global_position
	LevelManager.apply_player_data(player)
	RobotManager.spawn_saved_robots(self, player.global_position)
	
	# 2. FORCE PLAYER CAMERA
	# This overrides the stationary cameras from Level 1 & 2
	var p_cam = player.get_node_or_null("Camera2D")
	p_cam.enabled = true
	p_cam.make_current()
	
	# 3. Ensure player logic is actually running
	player.set_physics_process(true)
	player.show()
	
	# 4. Lock mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

func _input(event):
	if event.is_action_pressed("ui_cancel"): 
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
