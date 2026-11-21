extends Area2D

enum TerminalState { READY, LOCKED, DISABLED }

@onready var terminal = $Terminal
@onready var anim_sprite = $Door

@export var current_state: TerminalState = TerminalState.READY
@export var slide_distance := 90.0
@export var open_speed := 1.2
@export var should_teleport := false

var is_open := false

func _ready():
	self.body_entered.connect(_on_body_entered)
	anim_sprite.stop()
	anim_sprite.frame = 0
	
	# Initial visual check for state
	if current_state == TerminalState.LOCKED:
		terminal.get_node("Sprite2D").modulate = Color(1, 0.5, 0.5)

func can_interact() -> bool:
	return current_state == TerminalState.READY and not is_open

func interact(player_ref):
	if current_state != TerminalState.READY or is_open:
		return
		
	is_open = true
	terminal.get_node("Sprite2D").modulate = Color(1, 1, 1)

	# 1. Create the smooth animation for EVERYONE
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# Animate the sprite frames
	tween.tween_property(anim_sprite, "frame", 5, open_speed)
	
	# Animate the sliding physical parts (if they exist)
	if has_node("LeftDoor"): 
		tween.tween_property($LeftDoor, "position:x", $LeftDoor.position.x - slide_distance, open_speed)
	if has_node("RightDoor"): 
		tween.tween_property($RightDoor, "position:x", $RightDoor.position.x + slide_distance, open_speed)
	if has_node("TopDoor"): 
		tween.tween_property($TopDoor, "position:y", $TopDoor.position.y - slide_distance, open_speed)
	if has_node("DownDoor"): 
		tween.tween_property($DownDoor, "position:y", $DownDoor.position.y + slide_distance, open_speed)

	$AudioStreamPlayer2D.play()

func set_highlight(state: bool):
	# The terminal script calls this; we gate it based on Door's state
	var sprite = terminal.get_node("Sprite2D")
	
	if is_open or current_state != TerminalState.READY:
		sprite.modulate = Color(1, 1, 1)
		# Re-apply lock color if still locked
		if current_state == TerminalState.LOCKED and not is_open:
			sprite.modulate = Color(1, 0.5, 0.5)
		return
	
	sprite.modulate = Color(1.5, 1.5, 1.5) if state else Color(1, 1, 1)

# Inside door.gd
func _on_body_entered(body):
	if is_open and should_teleport and body.is_in_group("player_group"):
		print("Attempting teleport...")
		# Use the engine's 'Engine.has_singleton' check if you're paranoid
		# But usually, just calling the name works IF there is no local node named the same thing.
		LevelManager.load_next_level()
