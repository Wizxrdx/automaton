extends CharacterBody2D

@export var speed := 190.0
@export var acceleration := 15.0
@export var friction := 10.0
@export var separation_dist := 75.0
@export var follow_distance := 80.0

@onready var inventory_system = $Inventory 
@onready var movement: AnimatedSprite2D = $movement
@onready var move_sfx = $walk

var player: Node2D
var neighbors: Array = [] 
var current_anim = ""
var highlighted := false

# NEW: Tracks if a Robotic Arm is currently on its way to load this AGV
var is_reserved := false 

func _ready():
	RobotManager.register_robot(self)
	player = get_tree().get_first_node_in_group("player_group")
	add_to_group("agv")

func _physics_process(_delta: float) -> void:
	if not player: return
	if velocity.length() > 10:
		if not move_sfx.playing:
			move_sfx.play()
		# OPTIONAL: Change pitch based on speed for "juice"
		move_sfx.pitch_scale = lerp(move_sfx.pitch_scale, 0.8 + (velocity.length() / 200.0), 0.1)
	else:
		move_sfx.stop()
		
	var to_player = player.global_position - global_position
	var dist_sq = to_player.length_squared()
	var desired_velocity = Vector2.ZERO

	if dist_sq > (follow_distance * follow_distance):
		desired_velocity = to_player.normalized() * speed
	
	desired_velocity += _calculate_separation()

	if desired_velocity.length_squared() > 25:
		velocity = velocity.move_toward(desired_velocity, acceleration)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction)

	move_and_slide()
	
	if Engine.get_physics_frames() % 5 == 0:
		update_animation_optimized()

func _calculate_separation() -> Vector2:
	var force = Vector2.ZERO
	for n in neighbors:
		if n == self or not is_instance_valid(n): continue
		var diff = global_position - n.global_position
		var d_sq = diff.length_squared()
		if d_sq < (separation_dist * separation_dist):
			var d = sqrt(d_sq)
			var strength = (separation_dist - d) / separation_dist
			force += diff.normalized() * strength * speed
	return force

# --- INTERFACE FOR PLAYER & ROBOTS ---
func has_item() -> bool:
	return inventory_system.has_item()

func add_to_storage(item_type: String):
	inventory_system.add_item(item_type)
	is_reserved = false # Clear reservation once loaded

func take_from_storage() -> String:
	return inventory_system.take_item()

func set_highlight(state: bool):
	highlighted = state
	movement.modulate = Color(1.8, 1.8, 1.8) if highlighted else Color(1, 1, 1)

func update_animation_optimized() -> void:
	if velocity.length_squared() < 100:
		movement.stop()
		return
	var angle = velocity.angle() 
	var idx = int(round(angle / (PI / 4))) % 8
	var directions = ["east", "southeast", "south", "southwest", "west", "northwest", "north", "northeast"]
	var anim_name = directions[idx]
	if current_anim != anim_name:
		current_anim = anim_name
		movement.play(anim_name)
