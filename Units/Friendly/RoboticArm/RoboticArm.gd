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
@onready var move_sfx = $walk

var player: Node2D
var neighbors: Array = [] 
var current_anim = ""

var target_item: Node2D = null
var target_agv: Node2D = null
var target_enemy: Node2D = null

var is_mouse_hovering := false
var latch_start_time: int = 0

func _ready():
	RobotManager.register_robot(self)
	player = get_tree().get_first_node_in_group("player_group")
	add_to_group("robotic_arm")
	
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	pickup_area.body_entered.connect(_on_pickup_body_entered)

# --- HOVER DETECTION ---

func _on_mouse_entered():
	is_mouse_hovering = true

func _on_mouse_exited():
	is_mouse_hovering = false

# --- INPUT HANDLING ---

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# If we are latching OR moving to an enemy/item, RMB should kill the command
		if current_state != State.IDLE:
			_release_latch()

# --- THE COMMAND SYSTEM ---

func set_target(new_target: Node2D):
	# GUARD: Explicitly ensure we are clean before taking a new target
	if current_state != State.IDLE: return 
	
	if new_target.is_in_group("item"):
		var free_agv = _find_free_agv()
		if free_agv:
			target_item = new_target
			target_agv = free_agv
			target_agv.is_reserved = true 
			current_state = State.MOVING_TO_ITEM
		else:
			modulate = Color(2, 0.5, 0.5)
			await get_tree().create_timer(0.2).timeout
			modulate = Color(1, 1, 1)

	elif new_target.is_in_group("enemy"):
		target_enemy = new_target
		current_state = State.MOVING_TO_ITEM

func _find_free_agv() -> Node2D:
	var agvs = get_tree().get_nodes_in_group("agv")
	for agv in agvs:
		if not agv.has_item() and not agv.is_reserved:
			return agv
	return null

# --- LATCHING LOGIC ---

func _latch_onto_enemy(enemy: Node2D):
	# GUARD: Don't latch if we just cancelled or changed targets
	if current_state != State.MOVING_TO_ITEM: return
	
	target_enemy = enemy
	current_state = State.LATCHED
	
	var current_latch_id = Time.get_ticks_msec()
	latch_start_time = current_latch_id
	
	if enemy.has_method("incapacitate"):
		enemy.incapacitate()
	
	await get_tree().create_timer(5.0).timeout
	
	# Only auto-release if the ID still matches (wasn't cancelled or reset)
	if latch_start_time == current_latch_id and current_state == State.LATCHED:
		_release_latch()

func _release_latch():
	# KILL THE TIMER ID FIRST
	latch_start_time = 0 
	
	if is_instance_valid(target_enemy) and target_enemy.has_method("reactivate"):
		target_enemy.reactivate()
	
	# FORCE RESET EVERYTHING
	_reset_state()

func _reset_state() -> void:
	if is_instance_valid(target_agv): 
		target_agv.is_reserved = false 
	
	target_item = null
	target_agv = null
	target_enemy = null
	current_state = State.IDLE
	# Clear velocity so it doesn't "slide" into the next command
	velocity = Vector2.ZERO 

# --- PHYSICS ---

func _physics_process(_delta: float) -> void:
	if velocity.length() > 10:
		if not move_sfx.playing:
			move_sfx.play()
		# OPTIONAL: Change pitch based on speed for "juice"
		move_sfx.pitch_scale = lerp(move_sfx.pitch_scale, 0.8 + (velocity.length() / 200.0), 0.1)
	else:
		move_sfx.stop()

	match current_state:
		State.IDLE:
			if player:
				move_towards_target(player.global_position, follow_distance)
		State.MOVING_TO_ITEM:
			if is_instance_valid(target_item):
				move_towards_target(target_item.global_position, 0.0)
				if pickup_area.overlaps_area(target_item):
					_pick_up_item()
			elif is_instance_valid(target_enemy):
				move_towards_target(target_enemy.global_position, 0.0)
				if pickup_area.overlaps_body(target_enemy):
					_latch_onto_enemy(target_enemy)
			else:
				_reset_state()
		State.MOVING_TO_AGV:
			if is_instance_valid(target_agv):
				move_towards_target(target_agv.global_position, 0.0)
				if pickup_area.overlaps_body(target_agv):
					_load_onto_agv()
			else:
				_drop_item_on_ground()
				_reset_state()
		State.LATCHED:
			if is_instance_valid(target_enemy):
				global_position = target_enemy.global_position
				velocity = Vector2.ZERO
			else:
				_reset_state()

# --- SIGNALS ---

func _on_pickup_area_entered(area: Area2D) -> void:
	if current_state == State.MOVING_TO_ITEM:
		if area == target_item:
			_pick_up_item()
		elif is_instance_valid(target_enemy) and area.name == "InteractionArea" and area.get_parent() == target_enemy:
			_latch_onto_enemy(target_enemy)

func _on_pickup_body_entered(body: Node2D) -> void:
	if current_state == State.MOVING_TO_AGV and body == target_agv:
		_load_onto_agv()
	elif current_state == State.MOVING_TO_ITEM and is_instance_valid(target_enemy) and body == target_enemy:
		_latch_onto_enemy(body)

# --- MOVEMENT HELPERS ---

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
