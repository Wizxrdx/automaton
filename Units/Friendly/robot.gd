extends CharacterBody2D

@export var speed := 190.0
@export var acceleration := 15.0
@export var friction := 10.0

@export var separation_dist := 45.0
@export var follow_distance := 60.0

var player: Node2D

func _ready():
	add_to_group("robots")
	if not player:
		player = get_tree().get_first_node_in_group("player_group")

func _physics_process(_delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player_group")
		return

	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var desired_velocity = Vector2.ZERO

	# 1. Follow Player
	if dist > follow_distance:
		desired_velocity = to_player.normalized() * speed
	
	# 2. Add Soft Separation
	desired_velocity += calculate_separation_force()

	# 3. Smooth Movement
	if desired_velocity.length() > 5:
		velocity = velocity.move_toward(desired_velocity, acceleration)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction)

	move_and_slide()

func calculate_separation_force() -> Vector2:
	var force = Vector2.ZERO
	var neighbors = get_tree().get_nodes_in_group("robots")
	
	for n in neighbors:
		if n == self: continue
		var d = global_position.distance_to(n.global_position)
		if d < separation_dist:
			var push_dir = global_position - n.global_position
			var strength = (separation_dist - d) / separation_dist
			force += push_dir.normalized() * strength * speed
	return force
