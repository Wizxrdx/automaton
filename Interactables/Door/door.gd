extends Area2D

@onready var terminal = $Terminal

@export var slide_distance := 90.0
@export var open_speed := 1.2

var is_open := false

func _ready():
	self.body_entered.connect(_on_body_entered)

func interact(_player_ref):
	if is_open: return
	is_open = true

	# Force it to normal color immediately
	terminal.modulate = Color(1, 1, 1)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# --- AUTO-DETECTION LOGIC ---
	if has_node("LeftDoor"):
		tween.tween_property($LeftDoor, "position:x", $LeftDoor.position.x - slide_distance, open_speed)
	if has_node("RightDoor"):
		tween.tween_property($RightDoor, "position:x", $RightDoor.position.x + slide_distance, open_speed)
	if has_node("TopDoor"):
		tween.tween_property($TopDoor, "position:y", $TopDoor.position.y - slide_distance, open_speed)
	if has_node("DownDoor"):
		tween.tween_property($DownDoor, "position:y", $DownDoor.position.y + slide_distance, open_speed)

func set_highlight(state: bool):
	# HARD GATE: If door is open, we force normal color and EXIT.
	# This prevents the Player.gd from ever turning the glow back on.
	if is_open:
		terminal.modulate = Color(1, 1, 1)
		return
	
	terminal.modulate = Color(1.5, 1.5, 1.5) if state else Color(1, 1, 1)

func _on_body_entered(body):
	if is_open and body.is_in_group("player_group"):
		LevelManager.load_next_level()
