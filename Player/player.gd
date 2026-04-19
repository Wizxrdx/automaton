extends CharacterBody2D

@onready var ray = $InteractRay
@onready var sprite = $AnimatedSprite2D
@onready var thought_system = $thought
@onready var inventory = $Inventory

const SPEED = 200.0
var last_dir = Vector2.DOWN
var current_highlight = null
var nearby_item = null

var is_busy = false 

func _ready():
	add_to_group("player_group")
	add_to_group("robots")

func _physics_process(_delta: float) -> void:
	var dir = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized()
	
	if dir != Vector2.ZERO:
		last_dir = dir
		ray.target_position = last_dir * 50

	velocity = dir * SPEED
	move_and_slide()
	
	# Update Animations
	update_animation(dir)

func update_animation(dir: Vector2):
	if dir != Vector2.ZERO:
		# Walking Animations
		if abs(dir.x) > abs(dir.y):
			sprite.play("walk_east" if dir.x > 0 else "walk_west")
		else:
			sprite.play("walk_south" if dir.y > 0 else "walk_north")
	else:
		# Idle Animations (based on last_dir)
		if abs(last_dir.x) > abs(last_dir.y):
			sprite.play("idle_east" if last_dir.x > 0 else "idle_west")
		else:
			sprite.play("idle_south" if last_dir.y > 0 else "idle_north")

func _process(_delta):
	if is_busy: return

	var obj = ray.get_collider()
	var new_target = null

	if nearby_item != null and not inventory.has_item():
		new_target = nearby_item
	elif obj and obj.has_method("set_highlight"):
		new_target = obj

	if new_target != current_highlight:
		if current_highlight: current_highlight.set_highlight(false)
		if new_target: new_target.set_highlight(true)
		current_highlight = new_target

	if Input.is_action_just_pressed("interact"):
		if nearby_item != null and not inventory.has_item():
			inventory.add_item(nearby_item.get_item_type())
			thought_system.hide_thought() 
			nearby_item.queue_free()
			nearby_item = null
			return
		if obj and obj.has_method("interact"):
			obj.interact(self)
			
	if Input.is_action_just_pressed("drop_item"):
		if nearby_item != null and inventory.has_item():
			_handle_swap()
		elif inventory.has_item():
			_handle_normal_drop()

func _handle_swap():
	is_busy = true
	var ground_item_type = nearby_item.get_item_type()
	
	thought_system.hide_thought()
	nearby_item.queue_free()
	nearby_item = null
	
	await inventory.drop_and_spawn(global_position + last_dir * 25)
	
	inventory.add_item(ground_item_type)
	is_busy = false

func _handle_normal_drop():
	is_busy = true
	var dropped_node = await inventory.drop_and_spawn(global_position + last_dir * 25)
	is_busy = false
	
	if nearby_item == dropped_node:
		update_bubble_state()

func update_bubble_state():
	if nearby_item:
		thought_system.update_thought(nearby_item.get_item_type(), inventory.has_item())

func _on_pickup_area_area_entered(area):
	if is_busy: return
	if area.has_method("get_item_type"):
		nearby_item = area
		update_bubble_state()
		
func _on_pickup_area_area_exited(area):
	if area == nearby_item:
		nearby_item = null
		thought_system.hide_thought()
