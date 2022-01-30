extends Node2D

func _ready():
	$Timer.stop()
	get_node("Timer").stop()

func rand_number_up_to(maximum):
	return ceil(randf() * maximum)




func _on_Timer_timeout():
	print("YO")
	pass # Replace with function body.
