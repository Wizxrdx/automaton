extends StaticBody2D

@onready var parent = get_parent()

func _ready():
	add_to_group("terminal")

func can_interact() -> bool:
	if parent.has_method("can_interact"):
		return parent.can_interact()
	return false

func interact(player):
	# Just relay to door
	if parent.has_method("interact"):
		parent.interact(player)

func set_highlight(state: bool):
	# Just relay to door
	if parent.has_method("set_highlight"):
		parent.set_highlight(state)
