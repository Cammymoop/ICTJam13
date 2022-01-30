extends TileMap

var shape_owner_id: = 0

var tile_width: = 0

var cached_solid_tiles = null

var spikes: = 7

var orbs: = 12

var checkpoint_off = 18
var checkpoint_on = 19

var start_cellmap: = []
var checkpoint_cellmap: = []
var which_checkpoint = null

func _ready() -> void:
	tile_width = cell_size.x
	
	create_initial_cellmap()
	level_setup()

func reset_level() -> void:
	restore_initial_cellmap()
	level_setup()

func reset_to_checkpoint() -> void:
	if not which_checkpoint:
		reset_level()
		return
	load_checkpoint()
	level_setup()
	
func level_setup() -> void:
	make_collision_shapes()
	make_hitboxes()

func get_cell_rotations_v(pos):
	var x = pos.x
	var y = pos.y
	var ret = []
	ret.append(is_cell_transposed(x, y))
	ret.append(is_cell_x_flipped(x, y))
	ret.append(is_cell_y_flipped(x, y))
	return ret

func create_initial_cellmap() -> void:
	create_cellmap(start_cellmap)
func save_checkpoint() -> void:
	create_cellmap(checkpoint_cellmap)

func create_cellmap(cellmap: Array) -> void:
	var cells = get_used_cells()
	cellmap.clear()
	
	for c_pos in cells:
		var c = {"pos": c_pos, "value": get_cellv(c_pos)}
		var rotations = get_cell_rotations_v(c_pos)
		c['transpose'] = rotations[0]
		c['flip_x'] = rotations[1]
		c['flip_y'] = rotations[2]
		cellmap.append(c)

func restore_initial_cellmap() -> void:
	restore_cellmap(start_cellmap)
func load_checkpoint() -> void:
	restore_cellmap(checkpoint_cellmap)

func restore_cellmap(cellmap) -> void:
	clear()
	
	for c in cellmap:
		set_cellv(c['pos'], c['value'], c['flip_x'], c['flip_y'], c['transpose'])
	
	var rect = get_used_rect()
	update_bitmask_region(rect.position, rect.end)

func get_cam_bounds() -> Rect2:
	var tile_rect = get_used_rect()
	return Rect2(tile_rect.position * tile_width, tile_rect.size * tile_width)

func get_level_bounds() -> Rect2:
	return get_used_rect()

func map_to_world_centered(pos) -> Vector2:
	return map_to_world(pos) + Vector2(ceil(tile_width/2.0), ceil(tile_width/2.0))

func clear_orb(pos) -> void:
	pos = world_to_map(pos)
	set_cellv(pos, -1)
	
	clear_one_hitbox(pos)

func destroy_tile(pos) -> void:
	set_cellv(pos, -1)
	update_bitmask_area(pos)
	
	make_collision_shapes()

func create_tile(pos, index) -> void:
	set_cellv(pos, index)
	update_bitmask_area(pos)
	
	make_collision_shapes()

func get_solid_tiles() -> Array:
	if cached_solid_tiles:
		return cached_solid_tiles
	
	var ts = get_tileset()
	var solid_tiles = []
	for i in ts.get_tiles_ids():
		if ts.tile_get_shape_count(i) > 0:
			solid_tiles.append(i)
	cached_solid_tiles = solid_tiles
	return solid_tiles

func add_rectange_shape(tl_x, tl_y, width, height) -> void:
	var rect = RectangleShape2D.new()
	rect.extents = Vector2(width/2.0 * tile_width, height/2.0 * tile_width)
	
	var rect_position = Vector2(tl_x * tile_width, tl_y * tile_width) + rect.extents
	
	var owner_dummy = Node.new()
	
	var body = $LevelStuff/CollisionBody
	var owner_id = body.create_shape_owner(owner_dummy)
	body.shape_owner_set_transform(owner_id, Transform2D(0, rect_position))
	body.shape_owner_add_shape(owner_id, rect)

func clear_all_shapes():
	var body = $LevelStuff/CollisionBody
	var owners = body.get_shape_owners()
	
	for o in owners:
		body.shape_owner_clear_shapes(o)
		body.remove_shape_owner(o)

func clear_hitboxes() -> void:
	var hitboxes = $LevelStuff/SpikeHitbox.get_children()
	hitboxes.append_array($LevelStuff/OrbHitbox.get_children())
	hitboxes.append_array($LevelStuff/EndHitbox.get_children())
	hitboxes.append_array($LevelStuff/CPHitbox.get_children())
	
	for h in hitboxes:
		if h.name == "ExampleShape":
			continue
		h.queue_free()

# Orbs only
func clear_one_hitbox(h_pos) -> void:
	var hitboxes = $LevelStuff/OrbHitbox.get_children()
	
	for h in hitboxes:
		if h.name == "ExampleShape":
			continue
		var pos = world_to_map(h.global_position)
		if pos == h_pos:
			h.set_deferred('disabled', true)
			return

func hit_checkpoint(player_position) -> void:
	var min_dist = 100
	var min_pos = null
	
	for check_pos in get_used_cells_by_id(checkpoint_off):
		var dist:float = (player_position - map_to_world_centered(check_pos)).length()
		if dist < min_dist:
			min_dist = dist
			min_pos = check_pos
	
	if min_pos != null:
		for already_on in get_used_cells_by_id(checkpoint_on):
			set_cellv(already_on, checkpoint_off)
		set_cellv(min_pos, checkpoint_on)
	else:
		print_debug("error could not find checkpoint tile")
	
	min_dist = 100
	var min_hitbox = null
	for h in $LevelStuff/CPHitbox.get_children():
		if h.name == "ExampleShape":
			continue
		var dist:float = (player_position - h.global_position).length()
		if dist < min_dist:
			min_dist = dist
			min_hitbox = h
	
	if which_checkpoint:
		which_checkpoint.set_deferred("disabled", false)
	
	if min_hitbox:
		which_checkpoint = min_hitbox
		min_hitbox.set_deferred("disabled", true)
		save_checkpoint()
	else:
		print_debug("error could not find checkpoint hitbox")

func get_spawn_position() -> Vector2:
	if which_checkpoint:
		return which_checkpoint.global_position
	else:
		return $PlayerSpawn.global_position

func make_hitboxes() -> void:
	clear_hitboxes()
	var cells = get_used_cells_by_id(spikes)
	var example_shape = $LevelStuff/SpikeHitbox/ExampleShape
	
	for c in cells:
		var cell_pos = map_to_world(c)
		var new_shape = example_shape.duplicate()
		new_shape.name = "SHB"
		
		new_shape.global_position = cell_pos
		new_shape.disabled = false
		
		$LevelStuff/SpikeHitbox.add_child(new_shape)
	
	cells = get_used_cells_by_id(orbs)
	example_shape = $LevelStuff/OrbHitbox/ExampleShape
	
	for c in cells:
		var cell_pos = map_to_world(c)
		var new_shape = example_shape.duplicate()
		new_shape.name = "OHB"
		
		new_shape.global_position = cell_pos
		new_shape.disabled = false
		
		$LevelStuff/OrbHitbox.add_child(new_shape)
	
	example_shape = $LevelStuff/EndHitbox/ExampleShape
	for end in get_used_cells_by_id(8):
		var cell_pos = map_to_world(end + Vector2(1, 1))
		var new_shape = example_shape.duplicate()
		new_shape.name = "EHB"
		
		new_shape.global_position = cell_pos
		new_shape.disabled = false
		
		$LevelStuff/EndHitbox.add_child(new_shape)
	
	example_shape = $LevelStuff/CPHitbox/ExampleShape
	for checkpoint in get_used_cells_by_id(checkpoint_off):
		var cell_pos = map_to_world(checkpoint)
		var new_shape = example_shape.duplicate()
		new_shape.name = "CPHB"
		
		new_shape.global_position = cell_pos
		new_shape.disabled = false
		
		$LevelStuff/CPHitbox.add_child(new_shape)
	
	for current_checkpoint in get_used_cells_by_id(checkpoint_on):
		var cell_pos = map_to_world(current_checkpoint)
		var new_shape = example_shape.duplicate()
		new_shape.name = "CPHB"
		
		new_shape.global_position = cell_pos
		new_shape.disabled = true
		
		$LevelStuff/CPHitbox.add_child(new_shape)
		which_checkpoint = new_shape
		

func make_collision_shapes() -> void:
	clear_all_shapes()
	
	var solid_tiles = get_solid_tiles()
	
	var collision_rows = {}
	
	for cell_v in get_used_cells():
		var cell: = get_cellv(cell_v)
		if cell in solid_tiles:
			if not cell_v.y in collision_rows:
				collision_rows[cell_v.y] = []
			collision_rows[cell_v.y].append(cell_v.x)
	
	for row in collision_rows.values():
		row.sort()
	
	var ranges = {}
	for row_y in collision_rows:
		ranges[row_y] = []
		var row = collision_rows[row_y]
		
		var current_range = {'start': row[0]}
		var prev_x = null
		var first = true
		for x in row:
			if first:
				first = false
				prev_x = x
				continue
			if x-prev_x > 1:
				current_range['stop'] = prev_x
				ranges[row_y].append(current_range)
				current_range = {'start': x}
			
			prev_x = x
		current_range['stop'] = prev_x
		ranges[row_y].append(current_range)
	
	for y in ranges:
		for tile_range in ranges[y]:
			add_rectange_shape(tile_range['start'], y, tile_range['stop'] - tile_range['start'] + 1, 1)
		
