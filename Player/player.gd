extends CharacterBody2D

@onready var ray = $InteractRay
@onready var sprite = $AnimatedSprite2D
@onready var thought_system = $thought
@onready var inventory = $Inventory

const SPEED = 250.0
var last_dir = Vector2.DOWN
var current_highlight = null
var nearby_item = null

# NEW: Track all items in the pickup zone
var items_in_range = []

var is_busy = false 

func _ready():
	add_to_group("player_group")
	add_to_group("robots")

func _physics_process(_delta: float) -> void:
	# ... (Keep your movement and raycast logic as is) ...
	var dir = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized()
	
	if dir != Vector2.ZERO:
		last_dir = dir
		ray.target_position = last_dir * 50

	velocity = dir * SPEED
	move_and_slide()
	update_animation(dir)

func _process(_delta):
	if is_busy: return
	
	_update_closest_item()

	var obj = ray.get_collider()
	var new_target = null

	# Prioritize item on ground for highlighting, then raycast objects
	if nearby_item != null:
		new_target = nearby_item
	elif obj and obj.has_method("set_highlight"):
		new_target = obj

	if new_target != current_highlight:
		if current_highlight: current_highlight.set_highlight(false)
		if new_target: new_target.set_highlight(true)
		current_highlight = new_target

	# CONSOLIDATED INTERACT LOGIC
	if Input.is_action_just_pressed("interact"):
		# 1. SWAP: If hands full AND standing over an item
		if nearby_item != null and inventory.has_item():
			_handle_swap()
			return
			
		# 2. PICKUP: If hands empty AND standing over an item
		if nearby_item != null and not inventory.has_item():
			var item_to_pickup = nearby_item
			inventory.add_item(item_to_pickup.get_item_type())
			thought_system.hide_thought() 
			items_in_range.erase(item_to_pickup)
			item_to_pickup.queue_free()
			nearby_item = null
			return
			
		# 3. INTERACT: If looking at a machine/utility
		if obj and obj.has_method("interact"):
			obj.interact(self)
			
	# Separate Drop Logic (remains on its own key)
	if Input.is_action_just_pressed("drop_item"):
		if inventory.has_item():
			_handle_normal_drop()

# --- NEW UTILITY FUNCTIONS ---
func _update_closest_item():
	var closest_dist = INF
	var closest_item = null

	# Clean up any items that might have been deleted elsewhere
	items_in_range = items_in_range.filter(func(item): return is_instance_valid(item))

	for item in items_in_range:
		var dist = global_position.distance_to(item.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_item = item
	
	# If the closest item has changed, update the UI
	if closest_item != nearby_item:
		nearby_item = closest_item
		if nearby_item:
			update_bubble_state()
		else:
			thought_system.hide_thought()

func _on_pickup_area_area_entered(area):
	if area.has_method("get_item_type"):
		if not items_in_range.has(area):
			items_in_range.append(area)
		
func _on_pickup_area_area_exited(area):
	if items_in_range.has(area):
		items_in_range.erase(area)
		# _update_closest_item in the next frame will handle resetting nearby_item

# --- KEEP YOUR REMAINING FUNCTIONS ---

func _handle_swap():
	is_busy = true
	var ground_item_type = nearby_item.get_item_type()
	
	thought_system.hide_thought()
	items_in_range.erase(nearby_item)
	nearby_item.queue_free()
	nearby_item = null
	
	await inventory.drop_and_spawn(global_position + last_dir * 25)
	inventory.add_item(ground_item_type)
	is_busy = false

func _handle_normal_drop():
	is_busy = true
	await inventory.drop_and_spawn(global_position + last_dir * 25)
	is_busy = false

func update_bubble_state():
	if nearby_item:
		thought_system.update_thought(nearby_item.get_item_type(), inventory.has_item())

func update_animation(dir: Vector2):
	# ... (Keep your animation code) ...
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
