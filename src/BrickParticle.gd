extends Sprite

var velocity: = Vector2(0, 0)

var GRAVITY = 5.0

var v: = false

func _process(delta):
	position += velocity * delta
	
	velocity.y += GRAVITY
	

func set_velocity(vel):
	velocity = vel

func _on_Timer_timeout():
	queue_free()


func _on_SpinTimer_timeout():
	if v:
		flip_v = not flip_v
	else:
		flip_h = not flip_h
	
	v = not v
