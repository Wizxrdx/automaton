extends CharacterBody2D

enum State { IDLE, MOVING_TO_ITEM, MOVING_TO_AGV, LATCHED }
var current_state = State.IDLE

@export var speed := 190.0
@export var acceleration := 15.0
@export var friction := 10.0
@export var separation_dist := 45.0
@export var follow_distance := 60.0

@onready var inventory_system = $Inventory
@onready var movement: AnimatedSprite2D = $movement
@onready var pickup_area: Area2D = $PickupArea

var player: Node2D
var neighbors: Array = [] 
var current_anim = ""

var target_item: Node2D = null
var target_agv: Node2D = null
var target_enemy: Node2D = null

func _ready():
	RobotManager.register_robot(self)
	player = get_tree().get_first_node_in_group("player_group")
	add_to_group("robotic_arm")
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	pickup_area.body_entered.connect(_on_pickup_body_entered)

func _physics_process(_delta: float) -> void:
	match current_state:
		State.IDLE:
			if player:
				move_towards_target(player.global_position, follow_distance)
				
		State.MOVING_TO_ITEM:
			if is_instance_valid(target_item):
				move_towards_target(target_item.global_position, 0.0) 
			elif is_instance_valid(target_enemy):
				move_towards_target(target_enemy.global_position, 0.0)
			else:
				_reset_state()
				
		State.MOVING_TO_AGV:
			if is_instance_valid(target_agv):
				move_towards_target(target_agv.global_position, 0.0)
			else:
				# If AGV died or vanished while we were moving to it
				_drop_item_on_ground()
				_reset_state()
		
		State.LATCHED:
			if is_instance_valid(target_enemy):
				global_position = target_enemy.global_position
				velocity = Vector2.ZERO
			else:
				_reset_state()

# --- THE COMMAND SYSTEM ---

func set_target(new_target: Node2D):
	if current_state != State.IDLE: return 
	
	if new_target.is_in_group("item"):
		# CHECK FOR AGV FIRST
		var free_agv = _find_free_agv()
		if free_agv:
			target_item = new_target
			target_agv = free_agv
			target_agv.is_reserved = true # Lock it down now!
			current_state = State.MOVING_TO_ITEM
			print("Robot: AGV secured. Fetching item.")
		else:
			print("Robot: Command rejected. No free AGVs available.")
			# Visual feedback: flash red briefly maybe?
			modulate = Color(2, 0.5, 0.5)
			await get_tree().create_timer(0.2).timeout
			modulate = Color(1, 1, 1)

	elif new_target.is_in_group("enemy"):
		target_enemy = new_target
		current_state = State.MOVING_TO_ITEM

func _find_free_agv() -> Node2D:
	var agvs = get_tree().get_nodes_in_group("agv")
	for agv in agvs:
		# Check if AGV is not full and not already being headed to by another arm
		if not agv.has_item() and not agv.is_reserved:
			return agv
	return null

func _on_pickup_area_entered(area: Area2D) -> void:
	if current_state == State.MOVING_TO_ITEM:
		if area == target_item:
			_pick_up_item()
		elif area.get_parent().is_in_group("enemy"):
			_latch_onto_enemy(area.get_parent())

func _on_pickup_body_entered(body: Node2D) -> void:
	if current_state == State.MOVING_TO_AGV and body == target_agv:
		_load_onto_agv()
	elif current_state == State.MOVING_TO_ITEM and body.is_in_group("enemy"):
		_latch_onto_enemy(body)

func _latch_onto_enemy(enemy: Node2D):
	target_enemy = enemy
	current_state = State.LATCHED
	if enemy.has_method("incapacitate"):
		enemy.incapacitate()
	
	await get_tree().create_timer(5.0).timeout
	
	if is_instance_valid(target_enemy) and target_enemy.has_method("reactivate"):
		target_enemy.reactivate()
	_reset_state()

# --- MOVEMENT AND LOGIC ---

func move_towards_target(target_pos: Vector2, stop_distance: float) -> void:
	var to_target = target_pos - global_position
	var dist_sq = to_target.length_squared()
	var desired_velocity = Vector2.ZERO

	if dist_sq > (stop_distance * stop_distance):
		desired_velocity = to_target.normalized() * speed
	
	desired_velocity += _calculate_separation()

	if desired_velocity.length_squared() > 25:
		velocity = velocity.move_toward(desired_velocity, acceleration)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction)

	move_and_slide()
	update_animation_optimized()

func _pick_up_item() -> void:
	if not is_instance_valid(target_item): 
		_reset_state()
		return
		
	var item_type = target_item.get_item_type()
	inventory_system.add_item(item_type)
	target_item.queue_free() 
	
	# We already have target_agv reserved from set_target()
	current_state = State.MOVING_TO_AGV

func _load_onto_agv() -> void:
	if is_instance_valid(target_agv):
		var held_type = inventory_system.take_item()
		target_agv.add_to_storage(held_type) 
	_reset_state()

func _drop_item_on_ground() -> void:
	if inventory_system.has_item():
		var type = inventory_system.take_item()
		ItemManager.spawn_item(type, global_position) 

func _reset_state() -> void:
	if is_instance_valid(target_agv): 
		target_agv.is_reserved = false 
	target_item = null
	target_agv = null
	target_enemy = null
	current_state = State.IDLE

func _calculate_separation() -> Vector2:
	var force = Vector2.ZERO
	for n in neighbors:
		if n == self or not is_instance_valid(n): continue
		var diff = global_position - n.global_position
		var d_sq = diff.length_squared()
		if d_sq < (separation_dist * separation_dist):
			force += diff.normalized() * (separation_dist - sqrt(d_sq)) / separation_dist * speed
	return force

func update_animation_optimized() -> void:
	if velocity.length_squared() < 100: return
	var directions = ["east", "southeast", "south", "southwest", "west", "northwest", "north", "northeast"]
	var anim_name = directions[int(round(velocity.angle() / (PI / 4))) % 8]
	if current_anim != anim_name:
		current_anim = anim_name
		movement.play(anim_name)
