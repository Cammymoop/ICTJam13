extends TileMap

var shape_owner_id: = 0

var tile_width: = 0

var cached_solid_tiles = null

var spikes: = 7

func _ready() -> void:
	tile_width = cell_size.x
	
	level_setup()
	
func level_setup() -> void:
	make_collision_shapes()
	make_hitboxes()

func get_cam_bounds() -> Rect2:
	var tile_rect = get_used_rect()
	return Rect2(tile_rect.position * tile_width, tile_rect.size * tile_width)

func get_level_bounds() -> Rect2:
	return get_used_rect()

func map_to_world_centered(pos) -> Vector2:
	return map_to_world(pos) + Vector2(ceil(tile_width/2.0), ceil(tile_width/2.0))

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
	
	var body = $CollisionBody
	var owner_id = body.create_shape_owner(owner_dummy)
	body.shape_owner_set_transform(owner_id, Transform2D(0, rect_position))
	body.shape_owner_add_shape(owner_id, rect)

func clear_all_shapes():
	var body = $CollisionBody
	var owners = body.get_shape_owners()
	
	for o in owners:
		body.shape_owner_clear_shapes(o)
		body.remove_shape_owner(o)
	

func make_hitboxes() -> void:
	var cells = get_used_cells_by_id(spikes)
	var example_shape = $SpikeHitbox/ExampleShape
	
	for c in cells:
		var cell_pos = map_to_world(c)
		var new_shape = example_shape.duplicate()
		new_shape.name = "SHB"
		
		new_shape.global_position = cell_pos
		new_shape.disabled = false
		
		$SpikeHitbox.add_child(new_shape)

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
		
