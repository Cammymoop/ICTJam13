extends Sprite

var velocity: = Vector2(0, 0)

var GRAVITY = -0.04

var real_position: = Vector2(0, 0)

var waviness: = 3.0

var time_passed:float = 0.0

var shrink = false
var shrink_start = 0
var shrink_duration = .7

func _ready():
	time_passed += randf()
	
	waviness += randf() * 3 

func _process(delta):
	real_position += velocity * delta
	position = real_position + Vector2(sin(time_passed * 3.0) * waviness, 0)
	
	velocity.y += GRAVITY
	
	time_passed += delta
	
	if shrink:
		var x = 1 - (time_passed - shrink_start) / shrink_duration
		if x < 0:
			queue_free()
		scale = Vector2(x, x)

func set_position(pos):
	real_position = pos

func set_velocity(vel):
	velocity = vel

func _on_Timer_timeout():
	shrink = true
	shrink_start = time_passed
