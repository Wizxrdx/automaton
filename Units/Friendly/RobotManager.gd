extends Node

var all_robots: Array[CharacterBody2D] = []
const CELL_SIZE = 128 # The size of the "search square"

func register_robot(robot):
	all_robots.append(robot)

func _physics_process(_delta):
	# 1. Clean up the list if robots are deleted
	all_robots = all_robots.filter(func(bot): return is_instance_valid(bot))
	
	# 2. Sort robots into Grid Cells
	var grid = {}
	for bot in all_robots:
		var cell = Vector2(
			floor(bot.global_position.x / CELL_SIZE), 
			floor(bot.global_position.y / CELL_SIZE)
		)
		if not grid.has(cell): grid[cell] = []
		grid[cell].append(bot)
	
	# 3. Give each robot its neighbors (only from its own cell)
	for bot in all_robots:
		var cell = Vector2(
			floor(bot.global_position.x / CELL_SIZE), 
			floor(bot.global_position.y / CELL_SIZE)
		)
		# A robot only cares about robots in its own 128px square
		bot.neighbors = grid.get(cell, [])
