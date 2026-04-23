extends Node2D

@onready var player = $Player
@onready var spawn = $SpawnPoint

func _ready():
	player.global_position = spawn.global_position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event):
	if event.is_action_pressed("ui_cancel"): # This is the "Esc" key by default
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
