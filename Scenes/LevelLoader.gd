extends Node2D

var state: = "limbo"

var power_selected: = "destroy"

var level_selected = 1

var max_level = 4
var max_unlocked = 1

var arrows_on = false

func _ready() -> void:
	set_state("level_picking")

func _process(delta):
	if Input.is_action_just_pressed("cheat"):
		max_unlocked = max_level
	
	if state == "level_picking":
		if Input.is_action_just_pressed("move_right"):
			level_selected += 1
			if level_selected > max_unlocked:
				level_selected = 1
			get_selected_level()
		elif Input.is_action_just_pressed("move_left"):
			level_selected -= 1
			if level_selected < 1:
				level_selected = max_unlocked
			get_selected_level()
		
		if Input.is_action_just_pressed("jump"):
			set_state("power_picking")
		if Input.is_action_just_pressed("gaze"):
			set_state("brb")
	elif state == "power_picking":
		if Input.is_action_just_pressed("escape"):
			set_state("level_picking")
		
		if Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_left"):
			power_selected = "create" if power_selected == "destroy" else "destroy"
			show_power_being_picked()
		
		if Input.is_action_just_pressed("jump"):
			var player = find_player()
			if player:
				player.i_destroy = true if power_selected == "destroy" else false
				player.i_create = true if power_selected == "create" else false
			set_state("playing")
		if Input.is_action_just_pressed("gaze"):
			set_state("brb")

	elif state == "playing":
		if Input.is_action_just_pressed("escape"):
			set_state("power_picking")

func show_power_being_picked():
	hide_powers()
	
	var spr = get_node("Sprite_" + power_selected)
	spr.visible = true

func hide_powers():
	$Sprite_create.visible = false
	$Sprite_destroy.visible = false

func unlock_next():
	max_unlocked = min(max_level, max_unlocked + 1)
	level_selected = max_unlocked
	set_state("level_picking")

func find_player() -> Node:
	var f = get_tree().get_nodes_in_group("Player")
	if f:
		return f[0]
	return null

func load_level(level_name) -> void:
	var level_to_load = load("res://Scenes/Levels/" + level_name + ".tscn")
	if not level_to_load:
		print_debug("Could not find level: " + level_name)
	var loaded = level_to_load.instance()
	add_child(loaded)

func unload_level() -> void:
	var find = get_tree().get_nodes_in_group("Level")
	for level in find:
		level.queue_free()

func set_state(new_state) -> void:
	print_debug(new_state)
	hide_arrows()
	var player = find_player()
	if state == "playing":
		if player:
			player.set_active(false)
		$StaticCam.current = true
	if state == "power_picking":
		hide_powers()
		
	state = new_state
	
	if new_state == "playing":
		Engine.time_scale = 1.0
		get_tree().paused = false
		if player:
			player.spawn()
		$Cam.update_bounds()
		$Cam.current = true
	elif new_state == "power_picking":
		show_arrows()
		show_power_being_picked()
	elif new_state == "level_picking":
		show_arrows()
		get_selected_level()
		
		if max_unlocked == 1:
			set_state("power_picking")
	elif new_state == "brb":
		unload_level()
		load_level("BRB")
		set_state("playing")

func get_selected_level() -> void:
	unload_level()
	var level_name = "L" + str(level_selected)
	load_level(level_name)

func show_arrows():
	arrows_on = true
	$Arrows.visible = true
	$Blinky.start()

func hide_arrows():
	arrows_on = false
	$Arrows.visible = false
	$Blinky.stop()

func _on_Blinky_timeout():
	if arrows_on:
		if $Arrows.visible:
			$Blinky.wait_time = .2
		else:
			$Blinky.wait_time = .5
		$Blinky.start()
		$Arrows.visible = not $Arrows.visible
