extends Node2D

var level:TileMap
var enabled: = false

onready var target: = $Target

var cur_target_position:Vector2

var destroyable = [2]

var unplacable = [7]

func _ready():
	var f = get_tree().get_nodes_in_group("Level")
	if f:
		level = f[0]
		enabled = true
	else:
		print_debug("LEVEL NOT FOUND, PANIC!")
	
	$BreakSfx._build_buffer()

func _process(delta) -> void:
	if target.visible:
		target.global_position = cur_target_position

func _move(direction, vec: Vector2) -> Vector2:
	if direction == "up":
		return Vector2(vec.x, vec.y - 1)
	if direction == "down":
		return Vector2(vec.x, vec.y + 1)
	if direction == "left":
		return Vector2(vec.x - 1, vec.y)
	if direction == "right":
		return Vector2(vec.x + 1, vec.y)
	
	print_debug("Bad direction")
	return vec

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
	var solids = level.get_solid_tiles()
	var bounds:Rect2 = level.get_level_bounds()
	
	var tile_here = level.get_cellv(pos)
	while not tile_here in solids:
		pos = _move(direction, pos)
		if not in_bounds(pos, bounds):
			return null
		tile_here = level.get_cellv(pos)
	
	return pos
	

func hide_target() -> void:
	target.visible = false

func show_create_target(direction) -> bool:
	if not enabled:
		return false
	var target_pos = find_next_solid_tile(direction)
	if target_pos == null:
		return false
	target_pos = _move(reverse(direction), target_pos)
	
	var tile_here = level.get_cellv(target_pos)
	if tile_here in unplacable:
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
	
	$BreakSfx.play_sfx()
	spawn_destroy_particles()
	level.destroy_tile(target_pos)
	hide_target()

func create() -> void:
	if not target.visible:
		return
	var target_pos = level.world_to_map(cur_target_position)
	var tile_here = level.get_cellv(target_pos)
	if tile_here in unplacable:
		return
		
	$CreateSfx.play_sfx()
	spawn_create_particles()
	level.create_tile(target_pos, 2)
	hide_target()

func spawn_destroy_particles() -> void:
	pass

func spawn_create_particles() -> void:
	pass
