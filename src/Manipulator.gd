extends Node2D

var level:TileMap
var enabled: = false

onready var target: = $Target

var cur_target_position:Vector2

var destroyable = [2, 14, 15, 16, 17]

var unplacable = [7, 13, 20, 23, 21]
var untargetable = [13]
var restricter = [13]

var blocks_vision = [21]

var break_movers = {14: "up", 15: "down", 16: "left", 17: "right"}

var brick_particle_packed = preload("res://Scenes/BrickParticle.tscn")
var ring_particle_packed = preload("res://Scenes/PlaceParticle.tscn")

var max_range = 19

func _ready():
	$BreakSfx._build_buffer()
	$CreateSfx._build_buffer()

func start():
	var f = get_tree().get_nodes_in_group("Level")
	if f:
		level = f[0]
		enabled = true
	else:
		print_debug("LEVEL NOT FOUND, PANIC!")

func _process(delta) -> void:
	if target.visible:
		target.global_position = cur_target_position

func _move(direction, vec: Vector2, amount=1) -> Vector2:
	if direction == "up":
		return Vector2(vec.x, vec.y - amount)
	if direction == "down":
		return Vector2(vec.x, vec.y + amount)
	if direction == "left":
		return Vector2(vec.x - amount, vec.y)
	if direction == "right":
		return Vector2(vec.x + amount, vec.y)
	
	print_debug("Bad direction")
	return vec

func _world_move(direction, vec) -> Vector2:
	return _move(direction, vec, level.tile_width)

func get_current_grid_space() -> Vector2:
	return level.world_to_map(global_position)

func in_bounds(pos, bounds: Rect2) -> bool:
	#Rect2.encloses is exclusive on the right and bottom edge
	var bounds2 = Rect2(bounds.position, bounds.size + Vector2(1, 1))
	return bounds2.encloses(Rect2(pos, Vector2(0, 0)))

func reverse(direction) -> String:
	match direction:
		"up":
			return "down"
		"down":
			return "up"
		"left":
			return "right"
		"right":
			return "left"
		_:
			print_debug("Invalid direction")
			return ""

func find_next_solid_tile(direction):
	var pos = get_current_grid_space()
	var solids = []
	for t in level.get_solid_tiles():
		if not t in untargetable:
			solids.append(t)
	var bounds:Rect2 = level.get_level_bounds()
	
	var count = 1
	var tile_here = level.get_cellv(pos)
	while not tile_here in solids:
		pos = _move(direction, pos)
		if tile_here in blocks_vision or not in_bounds(pos, bounds):
			return null
		tile_here = level.get_cellv(pos)
		
		if count > max_range:
			return null
		count += 1
	
	return pos
	

func hide_target() -> void:
	target.visible = false

func show_create_target(direction, secondary_direction) -> bool:
	if not enabled:
		return false
	var target_pos = find_next_solid_tile(direction)
	#var targeted_tile = level.get_cellv(target_pos)
	if target_pos == null: # or targeted_tile in untargetable:
		return false
	
	var alt: = false
	target_pos = _move(reverse(direction), target_pos)
	var old = target_pos
	if direction == "down" and target_pos.y == get_current_grid_space().y:
		var target2 = _move(secondary_direction, _move(direction, target_pos))
		if not level.get_cellv(target2) in level.get_solid_tiles():
			alt = true
			target_pos = target2
	
	var tile_here = level.get_cellv(target_pos)
	if tile_here in unplacable:
		return false
	
	var restricted = false
	var loop = true
	
	while loop:
		loop = false
		var xs = [-1, 1, 0, 0]
		var ys = [0, 0, -1, 1]
		for i in range(4):
			var x = xs[i]
			var y = ys[i]
			if level.get_cell(x + target_pos.x, y + target_pos.y) in restricter:
				restricted = true
		if alt and restricted:
			target_pos = old
			restricted = false
			loop = true
			alt = false
	if restricted:
		return false
	
	target_on(target_pos)
	return true
	

func show_destroy_target(direction) -> bool:
	if not enabled:
		return false
	var target_pos = find_next_solid_tile(direction)
	if target_pos == null:
		return false
	
	var tile_here = level.get_cellv(target_pos)
	if not tile_here in destroyable:
		return false
	
	target_on(target_pos)
	return true

func target_on(target_pos) -> void:
	cur_target_position = level.map_to_world_centered(target_pos)
	target.global_position = cur_target_position
	target.visible = true

func destroy() -> void:
	if not target.visible:
		return
	var target_pos = level.world_to_map(cur_target_position)
	var tile_here = level.get_cellv(target_pos)
	if not tile_here in destroyable:
		return
	
	if tile_here in break_movers:
		var direction = break_movers[tile_here]
		var target2 = _move(direction, target_pos)
		var pos2 = _world_move(direction, cur_target_position)
		_create(target2, pos2, tile_here)
	
	_destroy(target_pos, cur_target_position)
	hide_target()

func _destroy(target_pos, world_pos):
	$BreakSfx.play_sfx()
	spawn_destroy_particles(world_pos)
	level.destroy_tile(target_pos)

func create() -> void:
	if not target.visible:
		return
	var target_pos = level.world_to_map(cur_target_position)
	var tile_here = level.get_cellv(target_pos)
	if tile_here in unplacable:
		return
	
	for other_dir in ["up", "down", "left", "right"]:
		var against_pos = _move(other_dir, target_pos)
		var against_tile = level.get_cellv(against_pos)
		if against_tile in break_movers and break_movers[against_tile] == other_dir:
			var pos2 = _world_move(other_dir, cur_target_position)
			_destroy(against_pos, pos2)
			_create(_move(other_dir, against_pos), _world_move(other_dir, pos2), against_tile)
		
	_create(target_pos, cur_target_position)
	hide_target()

func _create(target_pos, world_pos, tile_to_place=2):
	$CreateSfx.play_sfx()
	spawn_create_particles(world_pos)
	level.create_tile(target_pos, tile_to_place)

func spawn_destroy_particles(pos) -> void:
	for i in range(4):
		var p = brick_particle_packed.instance()
		var x_vel = 20.0 * ((i % 2) * 2 - 1)
		var y_vel = -60.0 * (1.5 if i >= 2 else 1)
		p.set_velocity(Vector2(x_vel, y_vel))
		level.add_child(p)
		p.global_position = pos

func spawn_create_particles(pos) -> void:
	for i in range(4):
		var p = ring_particle_packed.instance()
		var x_vel = 2.0 * ((i % 2) * 2 - 1)
		var x_pos = 4.0 * ((i % 2) * 2 - 1)
		var y_pos = 4.0 * (1 if i >= 2 else -1)
		p.set_velocity(Vector2(x_vel, 0))
		level.add_child(p)
		p.set_position(Vector2(x_pos + pos.x, y_pos + pos.y))
