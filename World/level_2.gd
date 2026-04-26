extends Node2D

@onready var player = $Player
@onready var spawn = $SpawnPoint

func _ready():
	player.global_position = spawn.global_position	
	LevelManager.apply_player_data(player)
	RobotManager.spawn_saved_robots(self, player.global_position)
	
	# HIDE THE LABELS (Assuming they are named like this)
	$Label.modulate.a = 0
	$Label2.modulate.a = 0
	$Label3.modulate.a = 0
	$Label4.modulate.a = 0

	self.show_tutorial_labels()

func show_tutorial_labels():
	# Put your label nodes in this list
	var labels = [$Label, $Label2, $Label3, $Label4]
	
	for l in labels:
		if l:
			var tween = create_tween()
			tween.tween_property(l, "modulate:a", 1.0, 0.5) # Smooth fade
			await get_tree().create_timer(3.0).timeout # 1 second gap

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event):
	if event.is_action_pressed("ui_cancel"): # This is the "Esc" key by default
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
