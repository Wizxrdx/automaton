extends StaticBody2D

enum TerminalState { READY, LOCKED, DISABLED }

@export var current_state: TerminalState = TerminalState.READY

@onready var parent = get_parent()
@onready var sprite = $Sprite2D

func interact(player):
	# Only allow interaction if the terminal is READY and the door isn't already open
	if current_state == TerminalState.READY and not parent.get("is_open"):
		if parent.has_method("interact"):
			parent.interact(player)
	else:
		print("Terminal is locked or disabled.")

func set_highlight(state: bool):
	# KILL highlight if: 
	# 1. Door is already open 
	# 2. Terminal is LOCKED or DISABLED
	if parent.get("is_open") or current_state != TerminalState.READY:
		sprite.modulate = Color(1, 1, 1)
		return
		
	# Standard highlight logic for READY state
	if state:
		sprite.modulate = Color(1.5, 1.5, 1.5)
	else:
		sprite.modulate = Color(1, 1, 1)

# Function to change state from other scripts (e.g., if a puzzle is solved)
func set_terminal_state(new_state: TerminalState):
	current_state = new_state
	# Optional: Change sprite color to show it's locked/disabled
	if current_state == TerminalState.LOCKED:
		sprite.modulate = Color(1, 0.5, 0.5) # Reddish tint
