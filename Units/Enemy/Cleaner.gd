extends CharacterBody2D

@export var patrol_speed := 90.0
@export var chase_speed := 160.0
@export var total_cleaning_time := 3.0 
@export var return_to_center_time := 2.0
@export var detection = true

enum State { PATROL, CLEANING, RETURNING, CHASE }
var current_state = State.PATROL

var current_direction := Vector2.DOWN 
var approach_direction := Vector2.DOWN 
var active := true

var cleaning_timer := 0.0
var scrub_timer := 0.0
var returning_timer := 0.0
var shuffle_dir := Vector2.ZERO

@onready var wall_sensor = $WallSensor 
@onready var detection_area = $DetectionArea 
@onready var sprite = $movement
@onready var flashlight = $DetectionArea/FlashlightVisual

func _ready():
	add_to_group("enemy")
	input_pickable = true
	flashlight.visible = detection
	
	if not detection_area.body_entered.is_connected(_on_vision_entered):
		detection_area.body_entered.connect(_on_vision_entered)
	
	wall_sensor.enabled = true
	wall_sensor.add_exception(self)
	_pick_random_direction()

func _physics_process(delta: float) -> void:
	if not active: return 
	
	match current_state:
		State.PATROL: _perform_patrol(delta)
		State.CLEANING: _perform_cleaning(delta)
		State.RETURNING: _perform_returning(delta)
		State.CHASE: _perform_chase(delta)

# --- 1. PATROL ---
func _perform_patrol(delta: float):
	velocity = current_direction * patrol_speed
	wall_sensor.target_position = current_direction * 35.0
	
	# Check for wall hit
	var collision = move_and_collide(velocity * delta, true)
	
	if wall_sensor.is_colliding() or collision != null:
		var target = wall_sensor.get_collider() if wall_sensor.is_colliding() else collision.get_collider()
		
		if target.is_in_group("player_group"):
			_trigger_chase()
			return
		else:
			# HIT WALL: Transition immediately
			approach_direction = current_direction 
			_start_cleaning()
			return
	
	move_and_slide()
	_update_sprite_animation(current_direction)

# --- 2. CLEANING: Side-to-Side (No Snapping) ---
func _start_cleaning():
	current_state = State.CLEANING
	cleaning_timer = total_cleaning_time
	scrub_timer = 0.0 
	
	# KILL MOMENTUM IMMEDIATELY
	# No more global_position teleporting. 
	velocity = Vector2.ZERO

func _perform_cleaning(delta: float):
	cleaning_timer -= delta
	scrub_timer -= delta
	
	if cleaning_timer <= 0:
		_start_returning()
		return

	# Side-to-side shuffle logic
	if scrub_timer <= 0:
		if approach_direction.y != 0: # Facing North/South wall
			shuffle_dir = Vector2.RIGHT if randf() > 0.5 else Vector2.LEFT
		else: # Facing East/West wall
			shuffle_dir = Vector2.DOWN if randf() > 0.5 else Vector2.UP
		
		scrub_timer = randf_range(0.4, 0.8)

	# We use a slight offset from the wall so move_and_slide doesn't friction-lock us.
	# But we do it via velocity, not teleporting.
	var slide_velocity = shuffle_dir * 80.0
	
	# Add a tiny bit of "push-back" force in the velocity 
	# to keep us from grinding into the wall's collision
	velocity = slide_velocity + (-approach_direction * 5.0)
	
	move_and_slide()
	_update_sprite_animation(approach_direction)

# --- 3. RETURNING ---
func _start_returning():
	current_state = State.RETURNING
	returning_timer = return_to_center_time

func _perform_returning(delta: float):
	returning_timer -= delta
	
	if returning_timer <= 0:
		_pick_random_direction()
		current_state = State.PATROL
		return
	
	velocity = -approach_direction * patrol_speed
	move_and_slide()
	_update_sprite_animation(velocity)

# --- 4. CHASE ---
func _perform_chase(_delta: float):
	var players = get_tree().get_nodes_in_group("player_group")
	if players.size() > 0:
		var player = players[0]
		var dir = global_position.direction_to(player.global_position)
		velocity = dir * chase_speed
		
		detection_area.look_at(player.global_position)
		detection_area.rotation_degrees -= 90 
		_update_sprite_animation(dir)
		
		if global_position.distance_to(player.global_position) > 400:
			_return_to_patrol()
	else:
		_return_to_patrol()
	
	move_and_slide()

# --- HELPERS ---

func _pick_random_direction():
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	if current_direction in dirs:
		dirs.erase(current_direction)
	current_direction = dirs.pick_random()
	_sync_orientation(current_direction)

func _trigger_chase():
	if current_state != State.CHASE:
		current_state = State.CHASE
		flashlight.modulate = Color(1, 0, 0, 0.8)

func _return_to_patrol():
	current_state = State.PATROL
	flashlight.modulate = Color(1, 1, 1, 0.4)
	_pick_random_direction()

func _sync_orientation(dir: Vector2):
	if dir == Vector2.DOWN: detection_area.rotation_degrees = 0
	elif dir == Vector2.UP: detection_area.rotation_degrees = 180
	elif dir == Vector2.RIGHT: detection_area.rotation_degrees = -90
	elif dir == Vector2.LEFT: detection_area.rotation_degrees = 90

func _update_sprite_animation(dir: Vector2):
	if dir.length() < 0.1: return
	if abs(dir.x) > abs(dir.y):
		sprite.play("east" if dir.x > 0 else "west")
	else:
		sprite.play("south" if dir.y > 0 else "north")

func _on_vision_entered(body: Node2D):
	if not active or body == self: return 
	if body.is_in_group("player_group"):
		_trigger_chase()

func incapacitate():
	active = false
	flashlight.visible = false
	velocity = Vector2.ZERO
	sprite.modulate = Color(0.3, 0.3, 0.3)
