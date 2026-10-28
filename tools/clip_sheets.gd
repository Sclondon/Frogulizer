extends SceneTree
## A contact sheet of a MoveClip played on the boy, the demade boy and a bigger, looser boy side by
## side: eight moments through its loop, each a row, from the front and three-quarters round. Given a
## folder instead, every clip in it on the boy alone: a row each, six moments along.
##   godot --path . --audio-driver Dummy --resolution 1200x500 --script tools/clip_sheets.gd -- <outdir> <res://moves/x.res> [frames]
##   godot --path . --audio-driver Dummy --resolution 400x500 --script tools/clip_sheets.gd -- <outdir> res://moves

const CELL := 1200

var figures: Array = []
var cam: Camera3D
var clip: MoveClip


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var every := DirAccess.dir_exists_absolute(args[1])
	if not every:
		clip = load(args[1])
	var count := int(args[2]) if args.size() > 2 else 8
	DirAccess.make_dir_recursive_absolute(out)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.56, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60, 2, 60)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	ground.add_child(collider)
	var visual := MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	visual.mesh.size = shape.size
	ground.add_child(visual)
	ground.position.y = -1
	stage.add_child(ground)
	var kinds := [[preload("res://models/boy.glb"), 1.0, 0.7], [preload("res://models/boy_lo.glb"), 1.0, 0.7], [preload("res://models/boy.glb"), 1.35, 1.0]]
	if every:
		kinds = [kinds[0]]
	for k in kinds.size():
		var figure: Figure = load("res://scripts/figure.gd").new()
		figure.model = kinds[k][0]
		figure.size = kinds[k][1]
		figure.looseness = kinds[k][2]
		figure.position = Vector3((k - 1) * 1.6 if not every else 0.0, 0.02, 0)
		stage.add_child(figure)
		figures.append(figure)
	cam = Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.make_current()
	if every:
		_every.call_deferred(out, args[1])
	else:
		_run.call_deferred(out, count)


func _every(out: String, folder: String) -> void:
	var files := Array(DirAccess.get_files_at(folder)).filter(func(f: String) -> bool: return f.ends_with(".res"))
	files.sort()
	var cells: Array[Image] = []
	var at := Vector3(0, 0.7, 0)
	cam.position = at + Vector3(1.9, 0.5, 2.6)
	cam.look_at(at)
	for file: String in files:
		clip = load(folder.path_join(file))
		var length := clip.loop_to - clip.loop_from
		for i in 6:
			var t := clip.loop_from + length * i / 6.0
			for step in 12:
				figures[0].rig.clip = clip
				figures[0].rig.clip_weight = 1.0
				figures[0].rig.clip_time = t - (11 - step) / 30.0
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.resize(200, 250)
			cells.append(image)
		print(file, " ", clip.title)
	var page := Image.create(200 * 6, 250 * files.size(), false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, 200, 250), Vector2i((i % 6) * 200, (i / 6) * 250))
	page.save_png(out.path_join("every_move.png"))
	print("SHEET ", out.path_join("every_move.png"))
	quit()


func _run(out: String, count: int) -> void:
	for f in 10:
		await process_frame
	var cells: Array[Image] = []
	var length := clip.loop_to - clip.loop_from
	for view in 2:
		var at := Vector3(0, 0.75, 0)
		cam.position = at + (Vector3(0, 0.4, 6.2) if view == 0 else Vector3(4.4, 0.6, 4.4))
		cam.look_at(at)
		for i in count:
			var t := clip.loop_from + length * i / count
			# (played up to the moment, so the springs have caught up)
			for step in 12:
				for figure: Figure in figures:
					figure.rig.clip = clip
					figure.rig.clip_weight = 1.0
					figure.rig.clip_time = t - (11 - step) / 30.0
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.resize(CELL / 2, CELL * image.get_height() / image.get_width() / 2)
			cells.append(image)
	var w := cells[0].get_width()
	var h := cells[0].get_height()
	var page := Image.create(w * 2, h * count, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, w, h), Vector2i((i / count) * w, (i % count) * h))
	var file := out.path_join(clip.resource_path.get_file().get_basename() + ".png")
	page.save_png(file)
	print("SHEET ", file)
	quit()
