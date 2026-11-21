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

	# Scan ALL colliders in InteractRay so walls/doors at index 0 never hide Terminals, Machines, or AGVs
	var best_interactable = null
	var best_interactable_dist = INF
	var best_agv = null
	var best_agv_dist = INF
	var player_has_item = inventory.has_item()

	for i in range(ray.get_collision_count()):
		var col = ray.get_collider(i)
		if not is_instance_valid(col):
			continue
		if col.has_method("interact"):
			var d = global_position.distance_squared_to(col.global_position)
			if d < best_interactable_dist:
				best_interactable_dist = d
				best_interactable = col
		elif col.has_method("add_to_storage"):
			if player_has_item or col.has_item():
				var d = global_position.distance_squared_to(col.global_position)
				if d < best_agv_dist:
					best_agv_dist = d
					best_agv = col

	var new_target = null

	# --- UPDATED SELECTION PRIORITY LOGIC ---
	if is_instance_valid(best_interactable):
		new_target = best_interactable
	elif is_instance_valid(best_agv):
		new_target = best_agv
	elif is_instance_valid(nearby_item):
		new_target = nearby_item

	# 3. HIGHLIGHT SYSTEM
	if new_target != current_highlight:
		if is_instance_valid(current_highlight) and current_highlight.has_method("set_highlight"):
			current_highlight.set_highlight(false)
			
		if is_instance_valid(new_target) and new_target.has_method("set_highlight"): 
			new_target.set_highlight(true)
			
		current_highlight = new_target
		update_bubble_state()

	# 4. INTERACTION INPUT — always act on whatever is currently highlighted
	if Input.is_action_just_pressed("interact"):
		if is_instance_valid(current_highlight):
			if current_highlight.has_method("interact"):
				var target = current_highlight
				if target.has_method("set_highlight"):
					target.set_highlight(false)
				current_highlight = null
				target.interact(self)
				update_bubble_state()
				return
			elif current_highlight.has_method("add_to_storage"):
				_handle_agv_interact(current_highlight)
				return
			elif current_highlight == nearby_item:
				if inventory.has_item():
					_handle_swap()
				else:
					_handle_pickup()
				return
		elif is_instance_valid(nearby_item):
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
	var did_swap = false
	if inventory.has_item() and not agv_obj.has_item():
		agv_obj.add_to_storage(inventory.held_item)
		inventory.consume_item()
	elif not inventory.has_item() and agv_obj.has_item():
		var item = agv_obj.take_from_storage()
		inventory.add_item(item)
	elif inventory.has_item() and agv_obj.has_item():
		var player_item = inventory.held_item
		var agv_item = agv_obj.take_from_storage()
		agv_obj.add_to_storage(player_item)
		inventory.add_item(agv_item)
		did_swap = true
	
	# After interacting, check if we should kill the highlight (e.g. if both are now empty)
	if not inventory.has_item() and not agv_obj.has_item():
		if agv_obj.has_method("set_highlight"):
			agv_obj.set_highlight(false)
		current_highlight = null
	
	update_bubble_state(did_swap)

func _handle_pickup():
	var item_to_pickup = nearby_item
	inventory.add_item(item_to_pickup.get_item_type())
	items_in_range.erase(item_to_pickup)
	item_to_pickup.queue_free()
	nearby_item = null
	update_bubble_state()

func _get_safe_drop_position(desired_pos: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var origin = global_position
	var to_target = desired_pos - origin
	var dist = to_target.length()
	if dist < 1.0:
		return origin

	# Check if a wall, closed door, or machine blocks the path from player feet to desired_pos
	var ray_query = PhysicsRayQueryParameters2D.create(origin, desired_pos, 1, [self])
	ray_query.collide_with_areas = false
	ray_query.collide_with_bodies = true
	var hit = space_state.intersect_ray(ray_query)

	var candidate = desired_pos
	if hit:
		var hit_dist = origin.distance_to(hit.position)
		var safe_dist = max(0.0, hit_dist - 16.0)
		candidate = origin + to_target.normalized() * safe_dist

	# Final check: ensure the candidate point itself isn't inside a world collider
	var point_query = PhysicsPointQueryParameters2D.new()
	point_query.position = candidate
	point_query.collision_mask = 1
	point_query.collide_with_areas = false
	point_query.collide_with_bodies = true
	point_query.exclude = [self]
	if space_state.intersect_point(point_query, 1).size() > 0:
		return origin

	return candidate

func _handle_swap():
	is_busy = true
	var type = nearby_item.get_item_type()
	var old_item = nearby_item
	var swap_pos = _get_safe_drop_position(old_item.global_position)
	items_in_range.erase(old_item)
	old_item.queue_free()
	var dropped = inventory.drop_and_spawn(swap_pos)
	inventory.add_item(type)
	nearby_item = dropped
	update_bubble_state(true)
	is_busy = false

func _handle_normal_drop():
	is_busy = true
	var drop_pos = _get_safe_drop_position(global_position + last_dir * 35)
	var dropped = inventory.drop_and_spawn(drop_pos)
	if is_instance_valid(dropped):
		nearby_item = dropped
	update_bubble_state()
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
		update_bubble_state()
		
	var closest_dist = INF
	var closest_item = null
	
	for item in items_in_range:
		var dist = global_position.distance_to(item.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_item = item
			
	if closest_item != nearby_item:
		nearby_item = closest_item
		update_bubble_state()

func _on_pickup_area_area_entered(area):
	if area.has_method("get_item_type"):
		if not items_in_range.has(area): items_in_range.append(area)
		
func _on_pickup_area_area_exited(area):
	if items_in_range.has(area): items_in_range.erase(area)

func update_bubble_state(force_pop: bool = false):
	if is_instance_valid(current_highlight) and current_highlight.has_method("add_to_storage") and current_highlight.has_item():
		thought_system.update_thought(current_highlight.inventory_system.held_item, inventory.has_item(), force_pop)
	elif is_instance_valid(nearby_item): 
		thought_system.update_thought(nearby_item.get_item_type(), inventory.has_item(), force_pop)
	else:
		thought_system.hide_thought()

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
	query.collide_with_bodies = true
	var results = space_state.intersect_point(query, 32)
	var found_item = null
	for hit in results:
		var col = hit.collider
		if not is_instance_valid(col):
			continue
		if col.is_in_group("enemy") and col.get("active") != false:
			return col
		if col.name == "InteractionArea" and col.get_parent() and col.get_parent().is_in_group("enemy"):
			var enemy = col.get_parent()
			if enemy.get("active") != false:
				return enemy
		if col.is_in_group("item") and found_item == null:
			found_item = col
	return found_item

func _issue_command(target):
	var arms = get_tree().get_nodes_in_group("robotic_arm")
	# Do not order another robot if any Robotic Arm is already targeting or latched onto this target
	for arm in arms:
		if is_instance_valid(arm) and (arm.target_enemy == target or arm.target_item == target):
			return

	var best_arm = null
	var min_dist = INF
	for arm in arms:
		if is_instance_valid(arm) and arm.current_state == arm.State.IDLE:
			var d = arm.global_position.distance_to(target.global_position)
			if d < min_dist:
				min_dist = d
				best_arm = arm
	if best_arm:
		best_arm.set_target(target)
