extends Node2D

@onready var player = $Player
@onready var spawn = $SpawnPoint
@onready var cleaner = $Cleaner

@export var is_menu_background := false

func _ready():
	# If we are embedded inside the MainMenu control, wait in menu background mode.
	if is_menu_background and get_parent() != get_tree().root:
		setup_menu_mode()
	else:
		# If Level1 is loaded directly (e.g. restarting after win or testing Level1), start gameplay.
		start_as_player()

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
	cleaner.queue_free()
	
	# Keep the ITEMS visible immediately
	$AGVMachine.visible = true
	$Battery.visible = true
	$Scrap.visible = true
	$Tires.visible = true
	
	# HIDE THE LABELS (Assuming they are named like this)
	$Label.modulate.a = 0
	$Label2.modulate.a = 0
	$Label3.modulate.a = 0
	$Label4.modulate.a = 0
	$Label5.modulate.a = 0
	$Label6.modulate.a = 0
	
	$Label.visible = true
	$Label2.visible = true
	$Label3.visible = true
	$Label4.visible = true
	$Label5.visible = true
	$Label6.visible = true
	
	player.show()
	player.velocity = Vector2.ZERO

	var static_cam = get_node_or_null("StaticLevelCamera")
	if static_cam:
		await get_tree().process_frame 
		static_cam.make_current()
	
	player.set_physics_process(true)
	player.set_process_input(true)

	# 2. TRIGGER THE TEXT SEQUENCE
	show_tutorial_labels()

func show_tutorial_labels():
	# Put your label nodes in this list
	var labels = [$Label, $Label2, $Label3, $Label4, $Label5, $Label6]
	
	for l in labels:
		if l:
			var tween = create_tween()
			tween.tween_property(l, "modulate:a", 1.0, 0.5) # Smooth fade
			await get_tree().create_timer(3.0).timeout # 1 second gap
