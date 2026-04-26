extends Node

var current_level_number = 1
var saved_item_type = null 

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
	var root = get_tree().root
	var current_level = null
	
	for child in root.get_children():
		if "Level" in child.name and child is Node2D:
			current_level = child
			break
	
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
	var canvas = CanvasLayer.new()
	get_tree().root.add_child(canvas)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	var label = Label.new()
	label.text = "FACILITY SECURED\n\nALL ROBOTS ACTIVE\n\nPress 'R' to Restart"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	canvas.add_child(label)

func _input(event):
	# Restart logic if player is on win screen
	if current_level_number > 5:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			current_level_number = 1
			saved_item_type = null
			get_tree().change_scene_to_file("res://World/Level1.tscn")
