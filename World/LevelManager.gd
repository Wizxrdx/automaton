extends Node

var current_level_number = 1
var saved_item_type = null 
var win_canvas: CanvasLayer = null
var caught_canvas: CanvasLayer = null
var is_caught: bool = false

func save_player_data(player_node):
	var inv = player_node.get_node_or_null("Inventory")
	if inv:
		saved_item_type = inv.held_item
		print("LevelManager: Saved item type -> ", saved_item_type)

func apply_player_data(player_node):
	var inv = player_node.get_node_or_null("Inventory")
	if inv and saved_item_type != null:
		inv.add_item(saved_item_type)
		print("LevelManager: Restored item type -> ", saved_item_type)

func load_next_level():
	if is_instance_valid(caught_canvas):
		caught_canvas.queue_free()
		caught_canvas = null
	is_caught = false

	var root = get_tree().root
	var current_level = null
	
	for child in root.get_children():
		if child.name == "MainMenu":
			child.queue_free()
		elif "Level" in child.name and child is Node2D:
			current_level = child
	
	if current_level and current_level.has_node("Player"):
		save_player_data(current_level.get_node("Player"))

	RobotManager.prepare_for_level_swap()

	if current_level:
		current_level.queue_free()

	current_level_number += 1
	
	# --- WIN CONDITION ---
	if current_level_number > 5:
		show_win_screen()
		return # Stop execution so it doesn't load Level 6
		
	var next_path = "res://World/Level" + str(current_level_number) + ".tscn"
	get_tree().change_scene_to_file(next_path)
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

# --- INSTANT WIN UI ---
func show_win_screen():
	if is_instance_valid(win_canvas):
		win_canvas.queue_free()
	win_canvas = CanvasLayer.new()
	get_tree().root.add_child(win_canvas)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_canvas.add_child(bg)
	
	var label = Label.new()
	label.text = "FACILITY SECURED\n\nALL ROBOTS ACTIVE\n\nPress 'R' to Restart"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	win_canvas.add_child(label)

# --- CAUGHT / LOSE CONDITION ---
func on_player_caught():
	if is_caught or current_level_number > 5:
		return
	is_caught = true
	
	# Freeze player and robots/enemies while overlay is shown
	for p in get_tree().get_nodes_in_group("player_group"):
		if is_instance_valid(p):
			p.is_busy = true
			p.velocity = Vector2.ZERO
			if p.has_node("walk"):
				p.get_node("walk").stop()
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.set_physics_process(false)
			if e.has_node("walk"):
				e.get_node("walk").stop()
	for bot in RobotManager.all_robots:
		if is_instance_valid(bot):
			bot.set_physics_process(false)
			if bot.has_node("walk"):
				bot.get_node("walk").stop()

	if is_instance_valid(caught_canvas):
		caught_canvas.queue_free()
	caught_canvas = CanvasLayer.new()
	get_tree().root.add_child(caught_canvas)

	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.0, 0.0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caught_canvas.add_child(bg)

	var label = Label.new()
	label.text = "CAUGHT BY CLEANER\n\nPress 'R' to Retry Level"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caught_canvas.add_child(label)

func restart_current_level():
	if is_instance_valid(caught_canvas):
		caught_canvas.queue_free()
		caught_canvas = null
	is_caught = false

	var root = get_tree().root
	for child in root.get_children():
		if "Level" in child.name and child is Node2D:
			child.queue_free()

	if current_level_number == 1:
		saved_item_type = null
		RobotManager.saved_robot_data.clear()
		RobotManager.level_start_robot_data.clear()
		RobotManager.all_robots.clear()
	else:
		RobotManager.restore_level_start_robots()

	var level_path = "res://World/Level" + str(current_level_number) + ".tscn"
	get_tree().change_scene_to_file(level_path)
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

func _input(event):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Debug shortcuts (active when running from the editor / debug builds)
	if OS.is_debug_build():
		if event.keycode == KEY_F9 and current_level_number <= 5:
			print("LevelManager [DEBUG]: Skipping to next level...")
			load_next_level()
			return
		elif event.keycode == KEY_F10:
			print("LevelManager [DEBUG]: Triggering Win Screen...")
			current_level_number = 5
			load_next_level()
			return

	# Retry current level if caught by a Cleaner
	if is_caught and event.keycode == KEY_R:
		restart_current_level()
		return

	# Restart logic if player is on win screen
	if current_level_number > 5 and event.keycode == KEY_R:
		if is_instance_valid(win_canvas):
			win_canvas.queue_free()
			win_canvas = null
		current_level_number = 1
		saved_item_type = null
		RobotManager.saved_robot_data.clear()
		RobotManager.level_start_robot_data.clear()
		RobotManager.all_robots.clear()
		get_tree().change_scene_to_file("res://World/Level1.tscn")
