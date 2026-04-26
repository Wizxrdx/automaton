extends Node

var all_robots: Array[CharacterBody2D] = []
const CELL_SIZE = 128

# NEW: The Data Vault for scene transitions
var saved_robot_data = [] 
var robot_scenes = {
	"robotic_arm": preload("res://Units/Friendly/RoboticArm/RoboticArm.tscn"),
	"agv": preload("res://Units/Friendly/AGV/AGV.tscn")
}

func register_robot(robot):
	all_robots.append(robot)

# --- NEW: SAVE/LOAD LOGIC ---

func prepare_for_level_swap():
	saved_robot_data.clear()
	for bot in all_robots:
		if is_instance_valid(bot):
			var type = "robotic_arm" if bot.is_in_group("robotic_arm") else "agv"
			saved_robot_data.append({
				"type": type,
				"item": bot.inventory_system.held_item
			})
	
	# After saving data, clear the physical node references
	all_robots.clear()

func spawn_saved_robots(level_node, spawn_pos: Vector2):
	for data in saved_robot_data:
		var scene = robot_scenes.get(data.type)
		if scene:
			var new_bot = scene.instantiate()
			level_node.add_child(new_bot)
			# Spread them out slightly around the player
			new_bot.global_position = spawn_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			
			# Restore inventory
			if data.item != null:
				new_bot.inventory_system.add_item(data.item)
	
	# Clear the saved data once spawned so we don't double-spawn later
	saved_robot_data.clear()

# --- EXISTING GRID LOGIC ---
func _physics_process(_delta):
	all_robots = all_robots.filter(func(bot): return is_instance_valid(bot))
	var grid = {}
	for bot in all_robots:
		var cell = Vector2(floor(bot.global_position.x / CELL_SIZE), floor(bot.global_position.y / CELL_SIZE))
		if not grid.has(cell): grid[cell] = []
		grid[cell].append(bot)
	
	for bot in all_robots:
		var cell = Vector2(floor(bot.global_position.x / CELL_SIZE), floor(bot.global_position.y / CELL_SIZE))
		bot.neighbors = grid.get(cell, [])
