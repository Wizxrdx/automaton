extends CharacterBody2D
@onready var ray = $InteractRay

const SPEED = 350.0
var last_dir = Vector2.DOWN

func _physics_process(delta: float) -> void:
	var dir = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized()
	
	if dir != Vector2.ZERO:
		last_dir = dir
		ray.target_position = last_dir * 50

	velocity = dir * SPEED
	move_and_slide()

func _process(delta):
	var obj = ray.get_collider()

	if obj:
		# TODO: check if Area
		print("Press E")

		if Input.is_action_just_pressed("interact") and obj.has_method("interact"):
			obj.interact()
