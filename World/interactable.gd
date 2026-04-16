extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect('body_entered', _on_enter)

func _on_enter(body):
	if body.name == 'Player':
		print('press E')

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func interact():
	print("Used")
