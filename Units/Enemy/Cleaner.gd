extends CharacterBody2D

@export var patrol_speed := 90.0
@export var chase_speed := 160.0
@export var total_cleaning_time := 10.0

enum State { PATROL, CLEANING, CHASE }
var current_state = State.PATROL

# You wanted Down as default, so we start here
var current_direction := Vector2.DOWN 
var active := true
var cleaning_timer := 0.0
var scrub_timer := 0.0
var shuffle_dir := Vector2.ZERO
var is_approaching_wall := false

@onready var wall_sensor = $WallSensor 
@onready var detection_area = $DetectionArea 
@onready var sprite = $movement
@onready var flashlight = $DetectionArea/FlashlightVisual

func _ready():
	add_to_group("enemy")
	if not detection_area.body_entered.is_connected(_on_vision_entered):
		detection_area.body_entered.connect(_on_vision_entered)
	
	wall_sensor.enabled = true
	wall_sensor.add_exception(self)
	
	# Force the light to match your 'Down' start
	_sync_orientation(current_direction)

func _physics_process(delta: float) -> void:
	if not active: return 
	
	match current_state:
		State.PATROL: _perform_patrol(delta)
		State.CLEANING: _perform_cleaning(delta)
		State.CHASE: _perform_chase(delta)

func _perform_patrol(_delta: float):
	var multiplier = 1.0 if is_approaching_wall else 0.6
	velocity = current_direction * (patrol_speed * multiplier)
	
	wall_sensor.target_position = current_direction * 45.0 
	
	if wall_sensor.is_colliding():
		var target = wall_sensor.get_collider()
		if target.is_in_group("walls") or target is TileMap:
			_start_cleaning()
		elif target.is_in_group("player_group"):
			_trigger_chase()
		else:
			current_direction = -current_direction
			wall_sensor.force_raycast_update()
			_sync_orientation(current_direction)
	
	move_and_slide()
	_update_sprite_animation(current_direction)

func _start_cleaning():
	current_state = State.CLEANING
	cleaning_timer = total_cleaning_time
	scrub_timer = 0.0 
	is_approaching_wall = false
	_sync_orientation(current_direction)
	velocity = Vector2.ZERO

func _perform_cleaning(delta: float):
	cleaning_timer -= delta
	scrub_timer -= delta
	
	if cleaning_timer <= 0:
		current_direction = -current_direction
		current_state = State.PATROL
		global_position += current_direction * 20.0 
		_sync_orientation(current_direction)
		return

	if scrub_timer <= 0:
		shuffle_dir = Vector2(current_direction.y, -current_direction.x) if randf() > 0.5 else Vector2.ZERO
		scrub_timer = 1.5 
	
	velocity = shuffle_dir * 40.0
	move_and_slide()
	_sync_orientation(current_direction)
	_update_sprite_animation(current_direction if shuffle_dir == Vector2.ZERO else shuffle_dir)

func _perform_chase(delta: float):
	var players = get_tree().get_nodes_in_group("player_group")
	if players.size() > 0:
		var player = players[0]
		velocity = global_position.direction_to(player.global_position) * chase_speed
		
		# We use look_at but SUBTRACT 90 degrees because your sprite faces Down
		detection_area.look_at(player.global_position)
		detection_area.rotation_degrees -= 90 
		
		_update_sprite_animation(velocity)
		if global_position.distance_to(player.global_position) > 400:
			_return_to_patrol()
	else:
		_return_to_patrol()
	move_and_slide()

func _return_to_patrol():
	current_state = State.PATROL
	flashlight.modulate = Color(1.0, 1.0, 1.0, 0.392)
	_sync_orientation(current_direction)

func _sync_orientation(dir: Vector2):
	# Since your flashlight faces DOWN at 0 degrees:
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
	elif body.is_in_group("walls") and current_state == State.PATROL:
		is_approaching_wall = true

func _trigger_chase():
	if current_state != State.CHASE:
		current_state = State.CHASE
		flashlight.modulate = Color(1.0, 0.0, 0.0, 0.392)

func incapacitate():
	active = false
	flashlight.visible = false

func reactivate():
	active = true
	flashlight.visible = true
