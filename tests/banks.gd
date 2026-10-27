extends SceneTree
## Photographs the land round the river (River, Farmland, FarLand), with the frame rate:
##   godot --path . --audio-driver Dummy --resolution 1280x720 --script tests/banks.gd -- <folder> [low | horizon]
## By itself: the banks from high over the river, both sides, a way ahead of the boat. "low": from
## about the height of the deck, looking across at the banks. "horizon": out to the horizon, high
## and low, to each side, ahead and behind (to see that the world has no edge).

var folder := "user://banks"
var mode := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		mode = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


## The views, [from, looking at], in the boat's space (it goes along +Z).
func _views() -> Array:
	var out := []
	match mode:
		"horizon":
			for side: float in [1.0, -1.0]:
				out.append([Vector3(0.0, 26.0, 0.0), Vector3(side * 220.0, 0.0, 40.0)])
				out.append([Vector3(side * 6.0, 4.0, -4.0), Vector3(side * 200.0, 9.0, 30.0)])
			out.append([Vector3(0.0, 32.0, -40.0), Vector3(0.0, 0.0, 320.0)])
			out.append([Vector3(0.0, 32.0, 40.0), Vector3(0.0, 0.0, -320.0)])
			out.append([Vector3(2.0, 4.0, -14.0), Vector3(25.0, 4.0, -300.0)])
			out.append([Vector3(0.0, 9.0, 21.0), Vector3(-30.0, 5.0, 300.0)])
		"low":
			for ahead: float in [20.0, 60.0, 100.0, 140.0]:
				for side: float in [1.0, -1.0]:
					out.append([Vector3(side * (River.SHORE - 10.0), 4.0, ahead), Vector3(side * (River.SHORE + 14.0), 1.5, ahead + 12.0)])
		_:
			for ahead: float in [10.0, 70.0, 130.0, 190.0]:
				for side: float in [1.0, -1.0]:
					out.append([Vector3(side * (River.SHORE - 12.0), 22.0, ahead - 30.0), Vector3(side * (River.SHORE + 18.0), 0.0, ahead + 20.0)])
	return out


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for frame in 10:
		await process_frame
	for layer in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	main.director.mode = "manual"
	for frame in 60:
		await process_frame
	var camera: Camera3D = main.director
	var views := _views()
	for k in views.size():
		var started := Time.get_ticks_msec()
		var frames := 0
		while Time.get_ticks_msec() - started < 800:
			var boat: Vector3 = main.boat.position
			camera.look_at_from_position(boat + views[k][0], boat + views[k][1])
			await process_frame
			frames += 1
		await RenderingServer.frame_post_draw
		var fps := frames / ((Time.get_ticks_msec() - started) / 1000.0)
		root.get_texture().get_image().save_png(folder.path_join("bank_%d.png" % k))
		print("view %d: %.0f fps" % [k, fps])
	quit()
