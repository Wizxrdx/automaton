extends CharacterBody2D

@export var patrol_speed := 90.0
@export var chase_speed := 160.0
@export var total_cleaning_time := 3.0 
@export var return_to_center_time := 2.0
@export var detection = true
@onready var move_sfx = $walk

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
var cone_poly: Polygon2D = null
const CONE_RADIUS := 228.0
const CONE_HALF_ANGLE := 0.473 # atan2(256 * 0.46, 230)
const CONE_RAYS := 24

# NEW: Dedicated large area for hover and click
@onready var interaction_area = $InteractionArea

func _ready():
	add_to_group("enemy")
	
	# Disable pickable on the body, enable it on the large Area
	input_pickable = false 
	interaction_area.input_pickable = true
	
	flashlight.visible = false
	_setup_cone_polygon()
	cone_poly.visible = detection
	
	# Connect Hover signals to the LARGE Area (left-click targeting is handled centrally in player.gd)
	interaction_area.mouse_entered.connect(_on_mouse_entered)
	interaction_area.mouse_exited.connect(_on_mouse_exited)
	
	if not detection_area.body_entered.is_connected(_on_vision_entered):
		detection_area.body_entered.connect(_on_vision_entered)
	
	wall_sensor.enabled = true
	wall_sensor.add_exception(self)
	_pick_random_direction()

# --- HOVER & CLICK LOGIC ---

func is_targeted_by_arm() -> bool:
	for robot in RobotManager.all_robots:
		if is_instance_valid(robot) and robot.is_in_group("robotic_arm"):
			if robot.get("target_enemy") == self:
				return true
	return false

func _on_mouse_entered():
	if not active or is_targeted_by_arm(): return
	
	var arm_available = false
	for robot in RobotManager.all_robots:
		if is_instance_valid(robot) and robot.is_in_group("robotic_arm"):
			if robot.current_state == 0: # State.IDLE
				arm_available = true
				break
	
	if arm_available:
		# Use a massive boost to make the whole sprite glow
		sprite.modulate = Color(2.5, 2.5, 2.5) 

func _on_mouse_exited():
	if not active:
		sprite.modulate = Color(0.3, 0.3, 0.3)
	else:
		sprite.modulate = Color(1, 1, 1)

# --- PHYSICS AND AI ---

func _physics_process(delta: float) -> void:
	if not active: return 
	
	if velocity.length() > 10:
		if not move_sfx.playing:
			move_sfx.play()
		# OPTIONAL: Change pitch based on speed for "juice"
		move_sfx.pitch_scale = lerp(move_sfx.pitch_scale, 0.8 + (velocity.length() / 200.0), 0.1)
	else:
		move_sfx.stop()
	
	match current_state:
		State.PATROL: _perform_patrol(delta)
		State.CLEANING: _perform_cleaning(delta)
		State.RETURNING: _perform_returning(delta)
		State.CHASE: _perform_chase(delta)

	if detection:
		_update_cone_polygon()
		if current_state != State.CHASE:
			_check_vision_cone()

func _perform_patrol(delta: float):
	velocity = current_direction * patrol_speed
	wall_sensor.target_position = current_direction * 35.0
	var collision = move_and_collide(velocity * delta, true)
	
	if wall_sensor.is_colliding() or collision != null:
		approach_direction = current_direction 
		_start_cleaning()
		return
	
	move_and_slide()
	_update_sprite_animation(current_direction)

func _start_cleaning():
	current_state = State.CLEANING
	cleaning_timer = total_cleaning_time
	scrub_timer = 0.0 
	velocity = Vector2.ZERO

func _perform_cleaning(delta: float):
	cleaning_timer -= delta
	scrub_timer -= delta
	if cleaning_timer <= 0:
		_start_returning()
		return
	if scrub_timer <= 0:
		if approach_direction.y != 0: 
			shuffle_dir = Vector2.RIGHT if randf() > 0.5 else Vector2.LEFT
		else: 
			shuffle_dir = Vector2.DOWN if randf() > 0.5 else Vector2.UP
		scrub_timer = randf_range(0.4, 0.8)
	velocity = (shuffle_dir * 80.0) + (-approach_direction * 5.0)
	move_and_slide()
	_update_sprite_animation(approach_direction)

func _start_returning():
	current_state = State.RETURNING
	returning_timer = return_to_center_time
	_sync_orientation(-approach_direction)

func _perform_returning(delta: float):
	returning_timer -= delta
	if returning_timer <= 0:
		_pick_random_direction()
		current_state = State.PATROL
		return
	velocity = -approach_direction * patrol_speed
	_sync_orientation(-approach_direction)
	move_and_slide()
	_update_sprite_animation(velocity)

func _perform_chase(_delta: float):
	var players = get_tree().get_nodes_in_group("player_group")
	if players.size() > 0:
		var player = players[0]
		if not _has_clear_los_to(player):
			_return_to_patrol()
			return
		var dist = global_position.distance_to(player.global_position)
		if chase_speed > 0.0 and dist <= 42.0:
			LevelManager.on_player_caught()
			return
		var dir = global_position.direction_to(player.global_position)
		velocity = dir * chase_speed
		detection_area.look_at(player.global_position + Vector2(0, -5))
		detection_area.rotation_degrees -= 90 
		_update_sprite_animation(dir)
		if dist > 400:
			_return_to_patrol()
	else:
		_return_to_patrol()
	move_and_slide()
	if chase_speed > 0.0:
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i).get_collider()
			if is_instance_valid(col) and col.is_in_group("player_group"):
				LevelManager.on_player_caught()
				return

func _pick_random_direction():
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	if current_direction in dirs:
		dirs.erase(current_direction)
	current_direction = dirs.pick_random()
	_sync_orientation(current_direction)

func _trigger_chase():
	if current_state != State.CHASE:
		current_state = State.CHASE
		if cone_poly:
			cone_poly.color = Color(1, 0, 0, 0.8)

func _return_to_patrol():
	current_state = State.PATROL
	if cone_poly:
		cone_poly.color = Color(1, 1, 1, 0.45)
	_pick_random_direction()

func _sync_orientation(dir: Vector2):
	if dir.length_squared() < 0.01:
		return
	if abs(dir.x) > abs(dir.y):
		detection_area.rotation_degrees = -90 if dir.x > 0 else 90
	else:
		detection_area.rotation_degrees = 0 if dir.y > 0 else 180

func _update_sprite_animation(dir: Vector2):
	if dir.length() < 0.1: return
	var dirs = ["east", "southeast", "south", "southwest", "west", "northwest", "north", "northeast"]
	var idx = posmod(int(round(dir.angle() / (PI / 4.0))), 8)
	sprite.play(dirs[idx])

func _setup_cone_polygon():
	if is_instance_valid(cone_poly):
		return
	cone_poly = Polygon2D.new()
	cone_poly.texture = flashlight.texture
	cone_poly.color = Color(1, 1, 1, 0.45)
	cone_poly.z_index = 1
	detection_area.add_child(cone_poly)

func _update_cone_polygon():
	if not is_instance_valid(cone_poly) or not cone_poly.visible:
		return
	var space_state = get_world_2d().direct_space_state
	var ray_origin = detection_area.global_position
	var rot = detection_area.global_rotation

	var pts = PackedVector2Array()
	var uvs = PackedVector2Array()
	pts.append(Vector2.ZERO)
	uvs.append(Vector2(128.0, 0.0))

	for i in range(CONE_RAYS + 1):
		var t = float(i) / float(CONE_RAYS)
		var angle = lerp(-CONE_HALF_ANGLE, CONE_HALF_ANGLE, t)
		var local_dir = Vector2(sin(angle), cos(angle))
		var world_dir = local_dir.rotated(rot)

		var query = PhysicsRayQueryParameters2D.create(ray_origin, ray_origin + world_dir * CONE_RADIUS, 1, [self])
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.hit_from_inside = true
		var hit = space_state.intersect_ray(query)

		var dist = CONE_RADIUS
		if hit:
			dist = ray_origin.distance_to(hit.position)

		var local_pt = local_dir * dist
		pts.append(local_pt)
		uvs.append(Vector2(128.0 + local_pt.x, local_pt.y))

	cone_poly.polygon = pts
	cone_poly.uv = uvs

func _has_clear_los_to(target: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var from_pos = detection_area.global_position
	var to_pos = target.global_position + Vector2(0, -5)
	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos, 1, [self])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	var hit = space_state.intersect_ray(query)
	return hit.is_empty()

func _check_vision_cone():
	for body in detection_area.get_overlapping_bodies():
		if is_instance_valid(body) and body.is_in_group("player_group"):
			if _has_clear_los_to(body):
				_trigger_chase()
				return

func _on_vision_entered(body: Node2D):
	if not active or not detection or body == self: return 
	if body.is_in_group("player_group") and _has_clear_los_to(body):
		_trigger_chase()

func incapacitate():
	active = false
	if is_instance_valid(cone_poly):
		cone_poly.visible = false
	velocity = Vector2.ZERO
	sprite.modulate = Color(0.3, 0.3, 0.3)
	# Disable the click area once it's already down
	interaction_area.input_pickable = false

func reactivate():
	sprite.modulate = Color(1, 1, 1)
	active = true
	if is_instance_valid(cone_poly):
		cone_poly.visible = detection
	interaction_area.input_pickable = true
	
