extends RigidBody2D

signal new_solid

var move_force:float = 20.0

var jumping:bool = false
var facing_right:bool = true

var current_anim:String = "idle"

var HEIGHT_FROM_FLOOR = 7

var JUMP_VELOCITY:float = 284.0
var STOP_JUMP_FORCE:float = 1100.0
var MOVE_FORCE:float = 600.0

var VEL_CAP:float = 120.0
var GROUND_DRAG:float = 350.0
var AIR_DRAG:float = 20.0

var FALL_THRESHOLD:float = 120.0

var death_plane = 10000000

var gazing: = false
export var i_destroy: = false
export var i_create: = true

var active: = false

var was_on_ground = false
var buffer_end = false

var hitbox_hold = false

var jump_buffer = 0
var JUMP_BUFFER_START = .14

var ground_buffer = 0
var GROUND_BUFFER_START = .2

var orbs: = 0
var checkpoint_orbs: = 0

var scores = {
	"create": {
		1: 0,
		2: 0,
		3: 0,
		4: 0,
		5: 0,
	},
	"destroy": {
		1: 0,
		2: 0,
		3: 0,
		4: 0,
		5: 0,
	}
}

func my_power():
	return "create" if i_create else "destroy"

func _ready():
	custom_integrator = true
	visible = active
	
	$JumpSfx._build_buffer()
	$GrabSfx._build_buffer()
	$WinSfx._build_buffer()
	$DeathSfx._build_buffer()
	#spawn()

func set_active(new_active) -> void:
	visible = new_active
	active = new_active

func spawn():
	set_active(true)
	$Manipulator.start()
	var f = get_tree().get_nodes_in_group("Level")
	if f:
		var level = f[0]
		death_plane = level.get_cam_bounds().end.y + 20
		
		var spawn_point = level.get_spawn_position()
		var offset = Vector2(level.tile_width/2, level.tile_width - HEIGHT_FROM_FLOOR)
		spawn_point = level.map_to_world(level.world_to_map(spawn_point)) + offset
		
		global_position = spawn_point
	else:
		print_debug("No level to spawn in!!")
	
	orbs = checkpoint_orbs
	
	linear_velocity = Vector2.ZERO
	
	if i_create:
		$Sprite.visible = false
		$Sprite2.visible = true
	else:
		$Sprite.visible = true
		$Sprite2.visible = false

func exit_level() -> void:
	orbs = 0
	checkpoint_orbs = 0

func _process(delta)-> void:
	if not active:
		return
		
	if Input.is_action_just_pressed("restart"):
		reset()
	
	if position.y > death_plane:
		reset()
	
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
			var found_target = $Manipulator.show_create_target(direction, "right" if facing_right else "left")
			if found_target:
				$GazeSfx.pitch_scale = 1.1 + (randf() * 0.5)
				$GazeSfx.play()
		$GazeTimer.start()
	if gazing and not Input.is_action_pressed("gaze"):
		$GazeTimer.stop()
		gazing = false
		show_gaze_eyes(false)
		$Manipulator.hide_target()
	
	if buffer_end and was_on_ground:
		var f = get_tree().get_nodes_in_group("Level")
		if f:
			var level = f[0]
			if $MiscZone.overlaps_area(level.get_node("EndHitbox")):
				real_end()
			else:
				buffer_end = false

func _integrate_forces(s):
	if not active:
		return
	
	var lv = s.get_linear_velocity()
	var step = s.get_step()

	var move_left: = Input.is_action_pressed("move_left")
	var move_right: = Input.is_action_pressed("move_right")
	var real_jump_press: = Input.is_action_just_pressed("jump")
	var real_jump_input: = Input.is_action_pressed("jump")
	
	if real_jump_press:
		jump_buffer = JUMP_BUFFER_START
	elif jump_buffer > 0:
		jump_buffer -= step
	
	var jump_input = jump_buffer > 0
	
	if ground_buffer > 0:
		ground_buffer -= step
	
	var buffered_ground = ground_buffer > 0
	
	var look_up: = Input.is_action_pressed("look_up")
	var look_down: = Input.is_action_pressed("look_down")

	var stopping_jump: = false
	# Process jump.
	if jumping:
		if lv.y > 0:
			# Set off the jumping flag if going down.
			jumping = false
		elif not real_jump_input:
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
		if not jumping and jump_input:
			$JumpSfx.play_sfx()
			lv.y = -JUMP_VELOCITY
			jumping = true
			stopping_jump = false
			jump_buffer = 0
			
			jump_collisionbox()
		
		if not jumping and is_jump_collisionbox():
			normal_collisionbox()

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
		
		# Check jump.
		if not jumping and real_jump_press and buffered_ground:
			$JumpSfx.play_sfx()
			lv.y = -JUMP_VELOCITY
			jumping = true
			stopping_jump = false
			jump_buffer = 0
			
			jump_collisionbox()

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
	
	was_on_ground = on_floor
	if on_floor:
		ground_buffer = GROUND_BUFFER_START

func jump_collisionbox() -> void:
	if hitbox_hold:
		return
	hitbox_hold = true
	$RealCollisionBoxJump.set_deferred('disabled', false)
	$RealCollisionBox.set_deferred('disabled', true)
	set_deferred('hitbox_hold', false)
func normal_collisionbox() -> void:
	if hitbox_hold:
		return
	hitbox_hold = true
	$RealCollisionBoxJump.set_deferred('disabled', true)
	$RealCollisionBox.set_deferred('disabled', false)
	set_deferred('hitbox_hold', false)
func is_jump_collisionbox() -> bool:
	return not $RealCollisionBoxJump.disabled

func reset() -> void:
	$DeathSfx.play_sfx()
	$Timers/DeathTimer.start()
	get_tree().paused = true

func reload_level() -> void:
	var f = get_tree().get_nodes_in_group("Level")
	if f:
		var level = f[0]
		level.reset_to_checkpoint()
	
	get_tree().paused = false
	
	spawn()

func win() -> void:
	get_tree().paused = false
	var f = get_tree().get_nodes_in_group("LevelLoader")
	if f:
		f[0].unlock_next()

func find_level():
	var f = get_tree().get_nodes_in_group("Level")
	if f:
		return f[0]
	return null
func find_level_loader():
	var f = get_tree().get_nodes_in_group("LevelLoader")
	if f:
		return f[0]
	return null

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
	if not active:
		return
	reset()

func _on_DamageZone_body_entered(body):
	if not active:
		return
	reset()

func _on_MiscZone_body_entered(body):
	if not active:
		return
	pass # Replace with function body.

func _on_MiscZone_area_shape_entered(_area_rid, area, area_shape_index, _local_shape_index):
	if not active:
		return
	#print_debug("touched " + area.name)
	if area.name == "OrbHitbox":
		var owner_index = area.shape_find_owner(area_shape_index)
		var owner_node = area.shape_owner_get_owner(owner_index)
		$GrabSfx.play_sfx()
		orbs += 1
		var f = get_tree().get_nodes_in_group("Level")
		if f:
			f[0].clear_orb(owner_node.global_position)
	elif area.name == "EndHitbox":
		var lvl = find_level_loader().get_current_level()
		scores[my_power()][lvl] = max(scores[my_power()][lvl], orbs)
		if was_on_ground:
			real_end()
		else:
			buffer_end = true
	elif area.name == "CPHitbox":
		checkpoint_orbs = orbs
		var level = find_level()
		if level:
			level.hit_checkpoint(global_position)

func get_score(level, power):
	return scores[power][level]

func real_end() -> void:
		get_tree().paused = true
		$WinSfx.play_sfx()
		$Timers/WinTimer.start()


func _on_new_solid(tile_pos):
	if not active:
		return
	var my_pos = $Manipulator.get_current_grid_space()
	if my_pos != tile_pos:
		return
	
	var level = find_level()
	
	#get pushed upwards, die if still inside a solid tile (squashed)
	var tw = level.tile_width
	global_position = Vector2(global_position.x, (floor(global_position.y/tw) * tw) - HEIGHT_FROM_FLOOR)
	
	if level.is_position_solid($Manipulator.get_current_grid_space()):
		global_position.y += HEIGHT_FROM_FLOOR
		reset()
	else:
		jumping = false
	
