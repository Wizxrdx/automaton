extends Node

const SETTINGS_PATH := "user://settings.cfg"
const PAUSE_MENU_SCENE := preload("res://UI/pause_menu.tscn")
const PIXEL_FONT := preload("res://UI/Pix32.ttf")

var current_level_number = 1
var saved_item_type = null 
var win_canvas: CanvasLayer = null
var caught_canvas: CanvasLayer = null
var pause_menu: CanvasLayer = null
var is_caught: bool = false
var music_volume: float = 1.0
var sfx_volume: float = 1.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_load_settings()
	set_music_volume(music_volume, false)
	set_sfx_volume(sfx_volume, false)
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	add_child(pause_menu)

func _ensure_audio_buses():
	if AudioServer.get_bus_index("Music") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

func _load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_volume = clamp(float(cfg.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
		sfx_volume = clamp(float(cfg.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)

func _save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(SETTINGS_PATH)

func _apply_bus_volume(bus_name: String, value: float):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, value <= 0.001)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(value, 0.0001)))

func set_music_volume(value: float, save: bool = true):
	music_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)
	if save:
		_save_settings()

func set_sfx_volume(value: float, save: bool = true):
	sfx_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)
	if save:
		_save_settings()

func return_to_main_menu():
	get_tree().paused = false
	if is_instance_valid(pause_menu):
		pause_menu.visible = false
	if is_instance_valid(win_canvas):
		win_canvas.queue_free()
		win_canvas = null
	if is_instance_valid(caught_canvas):
		caught_canvas.queue_free()
		caught_canvas = null
	is_caught = false

	var root = get_tree().root
	for child in root.get_children():
		if "Level" in child.name and child is Node2D:
			child.queue_free()

	current_level_number = 1
	saved_item_type = null
	RobotManager.saved_robot_data.clear()
	RobotManager.level_start_robot_data.clear()
	RobotManager.all_robots.clear()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")

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

func _build_overlay_screen(
	bg_color: Color,
	title_text: String,
	title_color: Color,
	subtitle_text: String,
	hint_text: String,
	primary_text: String,
	primary_cb: Callable,
	secondary_text: String,
	secondary_cb: Callable
) -> CanvasLayer:
	var canvas = CanvasLayer.new()
	canvas.layer = 20
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(canvas)

	var bg = ColorRect.new()
	bg.color = bg_color
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate.a = 0.0
	canvas.add_child(bg)

	var anchor = Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	anchor.scale = Vector2(0.31, 0.31)
	bg.add_child(anchor)

	var center_box = CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	anchor.add_child(center_box)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center_box.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", title_color)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.86, 0.89, 0.92))
	vbox.add_child(subtitle)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var primary_btn = Button.new()
	primary_btn.text = primary_text
	primary_btn.custom_minimum_size = Vector2(0, 38)
	primary_btn.button_up.connect(primary_cb)
	vbox.add_child(primary_btn)

	var secondary_btn = Button.new()
	secondary_btn.text = secondary_text
	secondary_btn.custom_minimum_size = Vector2(0, 38)
	secondary_btn.button_up.connect(secondary_cb)
	vbox.add_child(secondary_btn)

	var hint = Label.new()
	hint.text = hint_text
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.70))
	vbox.add_child(hint)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	primary_btn.grab_focus()

	var tween = canvas.create_tween().set_parallel(true)
	tween.tween_property(bg, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(anchor, "scale", Vector2(0.345, 0.345), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return canvas

func restart_from_level_1():
	if is_instance_valid(win_canvas):
		win_canvas.queue_free()
		win_canvas = null
	if is_instance_valid(caught_canvas):
		caught_canvas.queue_free()
		caught_canvas = null
	is_caught = false
	current_level_number = 1
	saved_item_type = null
	RobotManager.saved_robot_data.clear()
	RobotManager.level_start_robot_data.clear()
	RobotManager.all_robots.clear()
	get_tree().change_scene_to_file("res://World/Level1.tscn")
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

# --- WIN SCREEN ---
func show_win_screen():
	if is_instance_valid(win_canvas):
		win_canvas.queue_free()
	win_canvas = _build_overlay_screen(
		Color(0.03, 0.06, 0.05, 0.82),
		"FACILITY SECURED",
		Color(0.50, 0.95, 0.65),
		"All sectors cleared. Every robot is back online.",
		"Press [R] to Play Again",
		"Play Again",
		restart_from_level_1,
		"Main Menu",
		return_to_main_menu
	)

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
	caught_canvas = _build_overlay_screen(
		Color(0.14, 0.02, 0.02, 0.82),
		"CAUGHT BY CLEANER",
		Color(1.0, 0.38, 0.38),
		"Detected in Sector " + str(current_level_number) + ". Systems offline.",
		"Press [R] to Retry Level",
		"Retry Level",
		restart_current_level,
		"Main Menu",
		return_to_main_menu
	)

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

	# Pause menu toggle on Esc during active gameplay
	if event.is_action_pressed("ui_cancel"):
		var in_main_menu = get_tree().root.get_node_or_null("MainMenu") != null
		if not in_main_menu and current_level_number <= 5 and not is_caught and is_instance_valid(pause_menu):
			if pause_menu.visible:
				pause_menu.close_menu()
			else:
				pause_menu.open_menu()
			get_viewport().set_input_as_handled()
			return

	# Debug shortcuts (active when running from the editor / debug builds)
	if OS.is_debug_build() and not get_tree().paused:
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
		restart_from_level_1()
