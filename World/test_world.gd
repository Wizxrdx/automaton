extends Node2D

@onready var player = $Player
@onready var spawn = $SpawnPoint

func _ready():
	player.global_position = spawn.global_position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
