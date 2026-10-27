extends SceneTree
## Plays the show and photographs each of the Director's shots, with the frame
## rate: run it at a phone's shape and a desk's.
##   godot --path . --resolution 1280x720 --script tests/shots.gd -- <folder> [shot ...]
##   godot --path . --resolution 540x1100 --script tests/shots.gd -- <folder>

var folder := "user://shots"
var shots: Array = ["audience", "stage", "floor", "lead", "conductor", "crane", "bank", "wheel", "bow"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		shots = args.slice(1)
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for frame in 10:
		await process_frame
	main.hud.boarded.emit()
	main.hud._boarded = true
	main.hud._card.hide()
	var size := root.get_visible_rect().size
	var tag := "tall" if size.y > size.x else "wide"
	for frame in 120:
		await process_frame
	for shot: String in shots:
		main.director.mode = shot
		main.director.cut_to(shot)
		var started := Time.get_ticks_msec()
		var frames := 0
		while Time.get_ticks_msec() - started < 2500:
			await process_frame
			frames += 1
		await RenderingServer.frame_post_draw
		var fps := frames / ((Time.get_ticks_msec() - started) / 1000.0)
		root.get_texture().get_image().save_png(folder.path_join("%s_%s.png" % [tag, shot]))
		print("shot %s %s: %.0f fps, beat %.2f, lead %s, energy %.2f" % [tag, shot, fps, Groove.beat, Groove.lead, Groove.energy])
	quit()
