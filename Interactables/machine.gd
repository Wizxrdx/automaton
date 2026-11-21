extends StaticBody2D

@export var robot_scene = preload("res://Units/Friendly/AGV/AGV.tscn")
var highlighted := false

# Definition of what this machine needs
@export var recipe = {
	"battery": 1,
	"scrap": 1,
	"tires": 1
}

# Tracking what has been put in
var current_inventory = {
	"battery": 0,
	"scrap": 0,
	"tires": 0
}

var is_complete = false

@onready var recipe_label = $RecipeLabel

func _ready():
	add_to_group('machine')
	# Position label above the machine
	recipe_label.global_position = global_position + Vector2(-50, -80)
	recipe_label.hide()

func needs_item(item_type) -> bool:
	if is_complete or item_type == null:
		return false
	return recipe.has(item_type) and current_inventory.get(item_type, 0) < recipe[item_type]

func interact(player_ref):
	if is_complete:
		revive_robot(player_ref)
		return

	var held = player_ref.inventory.held_item
	
	# --- SHOW RECIPE UI ---
	_update_recipe_ui()
	_show_ui_temp()

	if held == null:
		return # Just showing the UI was enough

	# --- ITEM HANDOVER LOGIC ---
	if recipe.has(held) and current_inventory[held] < recipe[held]:
		current_inventory[held] += 1
		player_ref.inventory.consume_item()
		
		$put_item.play()
		
		# Refresh UI to show the new count
		_update_recipe_ui()
		check_recipe_completion()
	else:
		# Flash red or something to show "Invalid Item"
		recipe_label.modulate = Color(1, 0, 0)
		await get_tree().create_timer(0.5).timeout
		recipe_label.modulate = Color(1, 1, 1)

func _update_recipe_ui():
	var text = "NEEDS:\n"
	for item in recipe:
		var current = current_inventory[item]
		var required = recipe[item]
		# Shows checkmark if done, else shows the count
		var icon = "[OK] " if current >= required else "[  ] "
		text += icon + item.capitalize() + ": " + str(current) + "/" + str(required) + "\n"
	
	recipe_label.text = text

func _show_ui_temp():
	recipe_label.show()
	# Automatically hide after 4 seconds of no interaction
	var timer = get_tree().create_timer(4.0)
	timer.timeout.connect(func(): recipe_label.hide())

func check_recipe_completion():
	for item in recipe:
		if current_inventory[item] < recipe[item]:
			is_complete = false
			return
	
	is_complete = true
	recipe_label.text = "READY TO REVIVE!"
	recipe_label.modulate = Color(0, 1, 0) # Turn green
	$Sprite2D.modulate = Color(0.5, 1.0, 0.5) 

func revive_robot(player_ref):
	var robot = robot_scene.instantiate()
	if "player" in robot:
		robot.player = player_ref
	
	robot.global_position = global_position
	get_parent().add_child(robot)

	# --- THE FIX ---
	var sfx = $machine_revive
	remove_child(sfx)            # Unhook it from the dying machine
	get_parent().add_child(sfx)  # Hook it to the Level
	sfx.play()                   # Play it
	sfx.finished.connect(sfx.queue_free) # Delete the sound node when done
	
	queue_free()

func set_highlight(state: bool):
	highlighted = state
	if state:
		_update_recipe_ui()
		recipe_label.show()
	else:
		recipe_label.hide()
		
	if is_complete:
		$Sprite2D.modulate = Color(0.7, 1.0, 0.7) if highlighted else Color(0.5, 1.0, 0.5)
	else:
		$Sprite2D.modulate = Color(1, 1, 0.6) if highlighted else Color(1, 1, 1)
