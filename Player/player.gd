extends CharacterBody2D

@onready var ray = $InteractRay # Must be a ShapeCast2D in the editor
@onready var sprite = $AnimatedSprite2D
@onready var thought_system = $thought
@onready var inventory = $Inventory
@onready var move_sfx = $walk

const SPEED = 200.0
var last_dir = Vector2.DOWN
var current_highlight = null
var nearby_item = null
var items_in_range = []
var is_busy = false

func _ready():
	add_to_group("player_group")

func _physics_process(_delta: float) -> void:
	if is_busy: return
	
	if velocity.length() > 10:
		if not move_sfx.playing:
			move_sfx.play()
		# OPTIONAL: Change pitch based on speed for "juice"
		move_sfx.pitch_scale = lerp(move_sfx.pitch_scale, 0.8 + (velocity.length() / 200.0), 0.1)
	else:
		move_sfx.stop()
	
	var dir = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized()
	
	if dir != Vector2.ZERO:
		last_dir = dir
		ray.target_position = last_dir * 60 

	velocity = dir * SPEED
	move_and_slide()
	update_animation(dir)

func _process(_delta):
	if is_busy: return
	_update_closest_item()

	var ray_obj = null
	if ray.get_collision_count() > 0:
		ray_obj = ray.get_collider(0)

	var new_target = null

	# --- UPDATED SELECTION PRIORITY LOGIC ---
	if is_instance_valid(ray_obj) and ray_obj.has_method("interact"):
		new_target = ray_obj
		
	elif is_instance_valid(ray_obj) and ray_obj.has_method("add_to_storage"):
		# ONLY highlight the AGV if interaction is actually possible
		var player_has_item = inventory.has_item()
		var agv_has_item = ray_obj.has_item() # Assumes AGV.gd has this method
		
		if player_has_item or agv_has_item:
			new_target = ray_obj
			
	elif is_instance_valid(nearby_item):
		new_target = nearby_item

	# 3. HIGHLIGHT SYSTEM
	if new_target != current_highlight:
		if is_instance_valid(current_highlight) and current_highlight.has_method("set_highlight"):
			current_highlight.set_highlight(false)
			
		if is_instance_valid(new_target) and new_target.has_method("set_highlight"): 
			new_target.set_highlight(true)
			
		current_highlight = new_target

	# 4. INTERACTION INPUT
	if Input.is_action_just_pressed("interact"):
		if is_instance_valid(ray_obj):
			if ray_obj.has_method("interact"):
				if ray_obj.has_method("set_highlight"):
					ray_obj.set_highlight(false)
				current_highlight = null
				ray_obj.interact(self)
				return
				
			if ray_obj.has_method("add_to_storage"):
				# Only trigger the handler if a transfer is possible
				if inventory.has_item() or ray_obj.has_item():
					_handle_agv_interact(ray_obj)
				return
		
		if is_instance_valid(nearby_item):
			if inventory.has_item(): 
				_handle_swap()
			else: 
				_handle_pickup()
			return

	if Input.is_action_just_pressed("drop_item"):
		if inventory.has_item(): 
			_handle_normal_drop()

# --- INTERACTION HANDLERS ---

func _handle_agv_interact(agv_obj):
	if inventory.has_item() and not agv_obj.has_item():
		agv_obj.add_to_storage(inventory.held_item)
		inventory.consume_item()
	elif not inventory.has_item() and agv_obj.has_item():
		var item = agv_obj.take_from_storage()
		inventory.add_item(item)
	
	# After interacting, check if we should kill the highlight (e.g. if both are now empty)
	if not inventory.has_item() and not agv_obj.has_item():
		if agv_obj.has_method("set_highlight"):
			agv_obj.set_highlight(false)
		current_highlight = null

func _handle_pickup():
	var item_to_pickup = nearby_item
	inventory.add_item(item_to_pickup.get_item_type())
	thought_system.hide_thought() 
	items_in_range.erase(item_to_pickup)
	item_to_pickup.queue_free()
	nearby_item = null

func _handle_swap():
	is_busy = true
	var type = nearby_item.get_item_type()
	items_in_range.erase(nearby_item)
	nearby_item.queue_free()
	nearby_item = null
	await inventory.drop_and_spawn(global_position + last_dir * 35)
	inventory.add_item(type)
	is_busy = false

func _handle_normal_drop():
	is_busy = true
	await inventory.drop_and_spawn(global_position + last_dir * 35)
	is_busy = false

# --- ITEM DETECTION SYSTEM ---

func activate_camera(follow_player: bool):
	if follow_player:
		$Camera2D.enabled = true
		$Camera2D.make_current()
	else:
		$Camera2D.enabled = false

func _update_closest_item():
	items_in_range = items_in_range.filter(func(item): return is_instance_valid(item))
	
	if nearby_item and not is_instance_valid(nearby_item):
		nearby_item = null
		thought_system.hide_thought()
		
	var closest_dist = INF
	var closest_item = null
	
	for item in items_in_range:
		var dist = global_position.distance_to(item.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_item = item
			
	if closest_item != nearby_item:
		nearby_item = closest_item
		if is_instance_valid(nearby_item): 
			update_bubble_state()
		else: 
			thought_system.hide_thought()

func _on_pickup_area_area_entered(area):
	if area.has_method("get_item_type"):
		if not items_in_range.has(area): items_in_range.append(area)
		
func _on_pickup_area_area_exited(area):
	if items_in_range.has(area): items_in_range.erase(area)

func update_bubble_state():
	if is_instance_valid(nearby_item): 
		thought_system.update_thought(nearby_item.get_item_type(), inventory.has_item())

# --- ANIMATION & ROBOT COMMANDS ---

func update_animation(dir: Vector2):
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y): 
			sprite.play("walk_east" if dir.x > 0 else "walk_west")
		else: 
			sprite.play("walk_south" if dir.y > 0 else "walk_north")
	else:
		if abs(last_dir.x) > abs(last_dir.y): 
			sprite.play("idle_east" if last_dir.x > 0 else "idle_west")
		else: 
			sprite.play("idle_south" if last_dir.y > 0 else "idle_north")

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_target = _get_object_under_mouse()
		if clicked_target:
			_issue_command(clicked_target)

func _get_object_under_mouse():
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	var result = space_state.intersect_point(query)
	if result:
		return result[0].collider
	return null

func _issue_command(target):
	var arms = get_tree().get_nodes_in_group("robotic_arm")
	var best_arm = null
	var min_dist = INF
	for arm in arms:
		if arm.current_state == arm.State.IDLE:
			var d = arm.global_position.distance_to(target.global_position)
			if d < min_dist:
				min_dist = d
				best_arm = arm
	if best_arm:
		best_arm.set_target(target)
