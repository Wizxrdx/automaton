extends CharacterBody2D

@onready var ray = $InteractRay # This must be a ShapeCast2D in the editor
@onready var sprite = $AnimatedSprite2D
@onready var thought_system = $thought
@onready var inventory = $Inventory

const SPEED = 200.0
var last_dir = Vector2.DOWN
var current_highlight = null
var nearby_item = null
var items_in_range = []
var is_busy = false

func _ready():
	add_to_group("player_group")

func _physics_process(_delta: float) -> void:
	var dir = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized()
	
	if dir != Vector2.ZERO:
		last_dir = dir
		# Adjust the sweep direction of the ShapeCast
		ray.target_position = last_dir * 60 

	velocity = dir * SPEED
	move_and_slide()
	update_animation(dir)

func _process(_delta):
	if is_busy: return
	_update_closest_item()

	var obj = null
	if ray.get_collision_count() > 0:
		obj = ray.get_collider(0)

	var new_target = null

	# THE FIX: Priority 1 uses is_instance_valid to prevent holding dead items
	if is_instance_valid(nearby_item):
		new_target = nearby_item
	# Priority 2: AGV/Machines (ShapeCast)
	elif is_instance_valid(obj) and obj.has_method("set_highlight"):
		new_target = obj

	if new_target != current_highlight:
		# THE FIX: Ensure the old highlight target wasn't deleted before calling set_highlight
		if is_instance_valid(current_highlight) and current_highlight.has_method("set_highlight"):
			current_highlight.set_highlight(false)
			
		if is_instance_valid(new_target): 
			new_target.set_highlight(true)
			
		current_highlight = new_target

	if Input.is_action_just_pressed("interact"):
		if is_instance_valid(nearby_item):
			if inventory.has_item(): _handle_swap()
			else: _handle_pickup()
			return
			
		if is_instance_valid(obj):
			if obj.has_method("add_to_storage"):
				_handle_agv_interact(obj)
				return
			if obj.has_method("interact"):
				obj.interact(self)
				return

	if Input.is_action_just_pressed("drop_item"):
		if inventory.has_item(): _handle_normal_drop()

func _handle_agv_interact(agv_obj):
	if inventory.has_item() and not agv_obj.has_item():
		agv_obj.add_to_storage(inventory.held_item)
		inventory.consume_item()
	elif not inventory.has_item() and agv_obj.has_item():
		var item = agv_obj.take_from_storage()
		inventory.add_item(item)

func _handle_pickup():
	var item_to_pickup = nearby_item
	inventory.add_item(item_to_pickup.get_item_type())
	thought_system.hide_thought() 
	items_in_range.erase(item_to_pickup)
	item_to_pickup.queue_free()
	nearby_item = null

func _update_closest_item():
	# Scrape out any dead items deleted by the robots
	items_in_range = items_in_range.filter(func(item): return is_instance_valid(item))
	
	# FAILSAFE: If nearby_item somehow holds a dead reference, force the UI to hide
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

func update_bubble_state():
	if is_instance_valid(nearby_item): 
		thought_system.update_thought(nearby_item.get_item_type(), inventory.has_item())

func update_animation(dir: Vector2):
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y): sprite.play("walk_east" if dir.x > 0 else "walk_west")
		else: sprite.play("walk_south" if dir.y > 0 else "walk_north")
	else:
		if abs(last_dir.x) > abs(last_dir.y): sprite.play("idle_east" if last_dir.x > 0 else "idle_west")
		else: sprite.play("idle_south" if last_dir.y > 0 else "idle_north")
