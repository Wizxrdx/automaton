extends Node

var all_robots: Array[CharacterBody2D] = []
const CELL_SIZE = 128

# NEW: The Data Vault for scene transitions
var saved_robot_data = [] 
var level_start_robot_data = []
var player_trail: Array[Vector2] = []
const TRAIL_STEP := 24.0
const MAX_TRAIL_POINTS := 100
var robot_scenes = {
	"robotic_arm": preload("res://Units/Friendly/RoboticArm/RoboticArm.tscn"),
	"agv": preload("res://Units/Friendly/AGV/AGV.tscn")
}

func register_robot(robot):
	all_robots.append(robot)

# --- NEW: SAVE/LOAD LOGIC ---

func prepare_for_level_swap():
	saved_robot_data.clear()
	# If any Robotic Arm is mid-delivery to an AGV when leaving the level, complete the transfer onto its target AGV first
	for bot in all_robots:
		if is_instance_valid(bot) and bot.is_in_group("robotic_arm") and bot.inventory_system.has_item():
			var target_agv = bot.get("target_agv")
			if is_instance_valid(target_agv) and not target_agv.has_item():
				target_agv.add_to_storage(bot.inventory_system.take_item())
			else:
				for other in all_robots:
					if is_instance_valid(other) and other.is_in_group("agv") and not other.has_item():
						other.add_to_storage(bot.inventory_system.take_item())
						break
				# Never leave an item stuck on a Robotic Arm across level transitions
				if bot.inventory_system.has_item():
					bot.inventory_system.take_item()

	for bot in all_robots:
		if is_instance_valid(bot):
			var type = "robotic_arm" if bot.is_in_group("robotic_arm") else "agv"
			saved_robot_data.append({
				"type": type,
				"item": null if type == "robotic_arm" else bot.inventory_system.held_item
			})
	
	# Snapshot the state entering the next level so retrying the level restores it
	level_start_robot_data = saved_robot_data.duplicate(true)

	# After saving data, clear the physical node references
	all_robots.clear()
	player_trail.clear()

func restore_level_start_robots():
	saved_robot_data = level_start_robot_data.duplicate(true)
	all_robots.clear()
	player_trail.clear()

func spawn_saved_robots(level_node, spawn_pos: Vector2):
	var space_state = level_node.get_world_2d().direct_space_state if level_node is Node2D else null
	for data in saved_robot_data:
		var scene = robot_scenes.get(data.type)
		if scene:
			var new_bot = scene.instantiate()
			level_node.add_child(new_bot)
			# Spread them out slightly around the player, clamped inside walls
			var candidate = spawn_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			if space_state:
				var ray_query = PhysicsRayQueryParameters2D.create(spawn_pos, candidate, 1)
				ray_query.collide_with_areas = false
				ray_query.collide_with_bodies = true
				var hit = space_state.intersect_ray(ray_query)
				if hit:
					var to_cand = candidate - spawn_pos
					var safe_dist = max(0.0, spawn_pos.distance_to(hit.position) - 24.0)
					candidate = spawn_pos + to_cand.normalized() * safe_dist
			new_bot.global_position = candidate
			
			# Restore inventory
			if data.item != null:
				new_bot.inventory_system.add_item(data.item)
	
	# Clear the saved data once spawned so we don't double-spawn later
	saved_robot_data.clear()

# --- EXISTING GRID LOGIC + BREADCRUMB TRAIL ---
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

	var player = get_tree().get_first_node_in_group("player_group")
	if is_instance_valid(player):
		var p_pos = player.global_position
		if player_trail.is_empty():
			player_trail.append(p_pos)
		else:
			var last_dist = player_trail[player_trail.size() - 1].distance_to(p_pos)
			if last_dist > 200.0:
				player_trail.clear()
				player_trail.append(p_pos)
			elif last_dist >= TRAIL_STEP:
				player_trail.append(p_pos)
				if player_trail.size() > MAX_TRAIL_POINTS:
					player_trail.pop_front()

func _is_ray_clear(space_state: PhysicsDirectSpaceState2D, from_pos: Vector2, to_pos: Vector2, exclude: Array) -> bool:
	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos, 1, exclude)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	return space_state.intersect_ray(query).is_empty()

func get_follow_waypoint(robot: CharacterBody2D, player: Node2D, follow_distance: float) -> Dictionary:
	var space_state = robot.get_world_2d().direct_space_state
	var origin = robot.global_position + Vector2(0, -8)
	var player_center = player.global_position + Vector2(0, -5)
	if _is_ray_clear(space_state, origin, player_center, [robot]):
		return {"pos": player.global_position, "stop_dist": follow_distance}

	# Walk backwards along the player's breadcrumb trail and steer to the newest visible point
	for i in range(player_trail.size() - 1, -1, -1):
		var crumb = player_trail[i]
		if _is_ray_clear(space_state, origin, crumb + Vector2(0, -5), [robot]):
			return {"pos": crumb, "stop_dist": 12.0}

	return {"pos": player.global_position, "stop_dist": follow_distance}

func steer_around_obstacles(robot: CharacterBody2D, desired_dir: Vector2, prefer_side: int) -> Dictionary:
	if desired_dir.length_squared() < 0.001:
		return {"dir": Vector2.ZERO, "side": 0}
	var dir = desired_dir.normalized()
	var space_state = robot.get_world_2d().direct_space_state
	var origin = robot.global_position + Vector2(0, -8)
	var perp = Vector2(-dir.y, dir.x)
	var exclude = [robot]

	var center_clear = _is_ray_clear(space_state, origin, origin + dir * 36.0, exclude)
	var left_clear = _is_ray_clear(space_state, origin - perp * 16.0, origin - perp * 16.0 + dir * 30.0, exclude)
	var right_clear = _is_ray_clear(space_state, origin + perp * 16.0, origin + perp * 16.0 + dir * 30.0, exclude)

	if center_clear and left_clear and right_clear:
		return {"dir": dir, "side": 0}

	var first_side = prefer_side if prefer_side != 0 else (1 if right_clear and not left_clear else -1)
	var sides = [first_side, -first_side]
	var angles = [deg_to_rad(30.0), deg_to_rad(55.0), deg_to_rad(80.0), deg_to_rad(105.0)]

	for ang in angles:
		for s in sides:
			var cand = dir.rotated(ang * s)
			if _is_ray_clear(space_state, origin, origin + cand * 40.0, exclude):
				return {"dir": cand, "side": s}

	return {"dir": dir, "side": first_side}
