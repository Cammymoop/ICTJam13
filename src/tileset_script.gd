tool
extends TileSet

var levels = {13: 1, 3: 2, 2: 3}

func _is_tile_bound(drawn_id, neighbor_id) -> bool:
	if not drawn_id in levels:
		return false
	var lvl = levels[drawn_id]
	if neighbor_id in levels:
		if levels[neighbor_id] < lvl:
			return true
	return false
