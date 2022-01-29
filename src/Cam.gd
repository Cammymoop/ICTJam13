extends Camera2D

var following:Node2D

var above_level_bounds = 100

func _ready():
	following = get_tree().get_nodes_in_group("Player")[0]
	
	var f = get_tree().get_nodes_in_group("Level")
	if f:
		var level = f[0]
		var bounds:Rect2 = level.get_cam_bounds()
		
		limit_top = bounds.position.y - above_level_bounds
		limit_bottom = bounds.end.y
		limit_left = bounds.position.x
		limit_right = bounds.end.x

func _process(delta):
	global_position = following.global_position
