extends RigidBody2D

var move_force:float = 20.0

var jumping:bool = false
var facing_right:bool = true

var current_anim:String = "idle"

var JUMP_VELOCITY:float = 284.0
var STOP_JUMP_FORCE:float = 1100.0
var MOVE_FORCE:float = 600.0

var VEL_CAP:float = 120.0
var GROUND_DRAG:float = 180.0
var AIR_DRAG:float = 20.0

var FALL_THRESHOLD:float = 120.0

var death_plane = 10000000

var gazing: = false
export var i_destroy: = false
export var i_create: = true

func _ready():
	pass # Replace with function body.
	
	$JumpSfx._build_buffer()
	
	var f = get_tree().get_nodes_in_group("Level")
	if f:
		var level = f[0]
		death_plane = level.get_cam_bounds().end.y + 20
	
	if i_create:
		$Sprite.visible = false
		$Sprite2.visible = true
	else:
		$Sprite.visible = true
		$Sprite2.visible = false

func _process(delta)-> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	
	if position.y > death_plane:
		death()
	
	if Input.is_action_just_pressed("gaze"):
		var direction = "right" if facing_right else "left"
		var anim = $AnimationPlayer.assigned_animation
		if anim == "look_down":
			direction = "down"
		elif anim == "look_up":
			direction = "up" 
		
		gazing = true
		show_gaze_eyes(true)
		if i_destroy:
			var found_target = $Manipulator.show_destroy_target(direction)
			if found_target:
				$GazeSfx.pitch_scale = .9 + (randf() * 0.2)
				$GazeSfx.play()
		elif i_create:
			var found_target = $Manipulator.show_create_target(direction)
			if found_target:
				$GazeSfx.pitch_scale = 1.1 + (randf() * 0.5)
				$GazeSfx.play()
		$GazeTimer.start()
	if gazing and not Input.is_action_pressed("gaze"):
		$GazeTimer.stop()
		gazing = false
		show_gaze_eyes(false)
		$Manipulator.hide_target()

func _integrate_forces(s):
	var lv = s.get_linear_velocity()
	var step = s.get_step()

	var move_left: = Input.is_action_pressed("move_left")
	var move_right: = Input.is_action_pressed("move_right")
	var jump: = Input.is_action_pressed("jump")
	
	var look_up: = Input.is_action_pressed("look_up")
	var look_down: = Input.is_action_pressed("look_down")

	var stopping_jump: = false
	# Process jump.
	if jumping:
		if lv.y > 0:
			# Set off the jumping flag if going down.
			jumping = false
		elif not jump:
			stopping_jump = true

		if stopping_jump:
			lv.y += STOP_JUMP_FORCE * step
	
	var on_floor: = false
	
	for index in range(s.get_contact_count()):
		var ci = s.get_contact_local_normal(index)

		if ci.dot(Vector2(0, -1)) > 0.6:
			on_floor = true
	
	var new_anim: = current_anim

	if on_floor:
		# Process logic when character is on floor.
		if move_left and not move_right:
			if lv.x > -VEL_CAP:
				lv.x -= MOVE_FORCE * step
				if lv.x < -VEL_CAP:
					lv.x = -VEL_CAP
			facing_right = false
		elif move_right and not move_left:
			if lv.x < VEL_CAP:
				lv.x += MOVE_FORCE * step
				if lv.x > VEL_CAP:
					lv.x = VEL_CAP
			facing_right = true
		else:
			var xv = abs(lv.x)
			xv -= GROUND_DRAG * step
			if xv < 0:
				xv = 0
			lv.x = sign(lv.x) * xv

		# Check jump.
		if not jumping and jump:
			$JumpSfx.play_sfx()
			lv.y = -JUMP_VELOCITY
			jumping = true
			stopping_jump = false

		if jumping:
			new_anim = "jumping"
		elif abs(lv.x) < 0.1:
			if look_up and not look_down:
				new_anim = "look_up"
			elif look_down and not look_up:
				new_anim = "look_down"
			else:
				new_anim = "idle"
		else:
			new_anim = "running"
	else:
		# Process logic when the character is in the air.
		if move_left and not move_right:
			if lv.x > -VEL_CAP:
				lv.x -= MOVE_FORCE * step
				if lv.x < -VEL_CAP:
					lv.x = -VEL_CAP
			facing_right = false
		elif move_right and not move_left:
			if lv.x < VEL_CAP:
				lv.x += MOVE_FORCE * step
				if lv.x > VEL_CAP:
					lv.x = VEL_CAP
			facing_right = true
		else:
			var xv = abs(lv.x)
			xv -= AIR_DRAG * step

			if xv < 0:
				xv = 0
			lv.x = sign(lv.x) * xv

		if lv.y < FALL_THRESHOLD:
			new_anim = "jumping"
		else:
			new_anim = "falling"

	# Change animation.
	if new_anim != current_anim:
		current_anim = new_anim
		$AnimationPlayer.play(current_anim)
	
	var current_facing = true if $Sprite.scale.x != -1 else false
	if facing_right != current_facing:
		set_sprite_scale(1 if facing_right else -1)
		set_sprite_x(.5 if facing_right else -.5)

	# Finally, apply gravity and set back the linear velocity.
	lv += s.get_total_gravity() * step
	s.set_linear_velocity(lv)

func death() -> void:
	get_tree().reload_current_scene()

func set_sprite_scale(scale) -> void:
	$Sprite.scale.x = scale
	$Sprite2.scale.x = scale

func set_sprite_x(x) -> void:
	$Sprite.position.x = x
	$Sprite2.position.x = x

func show_gaze_eyes(show) -> void:
	$Sprite/GazeEyes.visible = show
	$Sprite2/GazeEyes.visible = show
	
func _on_GazeTimer_timeout():
	if not gazing:
		return
	gazing = false
	show_gaze_eyes(false)
	
	if i_destroy:
		$Manipulator.destroy()
	elif i_create:
		$Manipulator.create()


func _on_DamageZone_area_entered(area):
	death()


func _on_DamageZone_body_entered(body):
	death()
