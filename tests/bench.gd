extends SceneTree
## The band and a few dancers on a plain floor, with a song playing, photographed
## from a few sides: to check the frogs, their instruments and their moves.
##   godot --path . --resolution 1280x720 --script tests/bench.gd -- <folder> [seconds between shots]

var folder := "user://bench"
var gap := 1.3


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		gap = float(args[1])
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.55, 0.28)
	floor_mesh.material_override = mat
	floor_body.add_child(floor_mesh)
	world.add_child(floor_body)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.shadow_enabled = true
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.38, 0.45)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(env)

	var player := TrackPlayer.new()
	world.add_child(player)
	var parts := ["tuba", "trumpet", "clarinet", "accordion", "fiddle", "banjo", "drums"]
	var band := {}
	for k in parts.size():
		var frog := Frog.new()
		frog.look = FrogLook.bandsman(k)
		frog.part = parts[k]
		frog.position = Vector3(-3.0 + k * 1.0, 0.0, 0.0)
		frog.add_to_group(&"band")
		world.add_child(frog)
		band[parts[k]] = frog
	var conductor := Frog.new()
	conductor.look = FrogLook.bandsman(9, true)
	conductor.part = "conductor"
	conductor.position = Vector3(0.0, 0.0, 1.8)
	world.add_child(conductor)
	conductor.turn_to(PI)
	var dances := ["bounce", "clap", "wave", "jig", "sway", "watch"]
	for k in dances.size():
		var frog := Frog.new()
		frog.look = FrogLook.random(k + 20)
		frog.dance = dances[k]
		frog.position = Vector3(-2.5 + k * 1.0, 0.0, 3.4)
		world.add_child(frog)
		frog.turn_to(PI)
	player.struck.connect(func(part: String, loud: float) -> void:
		if part == "kick" or part == "cymbal":
			band.drums.frog_rig().strike(loud, part)
		elif band.has(part):
			band[part].frog_rig().strike(loud))
	player.play(0)

	var camera := Camera3D.new()
	camera.fov = 40
	world.add_child(camera)
	var views := [
		["band", Vector3(0, 1.6, 5.5), Vector3(0, 0.9, 0)],
		["left", Vector3(-3.0, 1.3, 1.6), Vector3(-2.5, 1.0, 0)],
		["mid", Vector3(0.0, 1.3, 1.7), Vector3(0.0, 1.0, 0)],
		["right", Vector3(2.4, 1.3, 1.7), Vector3(2.5, 0.9, 0)],
		["crowd", Vector3(0, 1.4, 7.0), Vector3(0, 0.9, 3.4)],
		["conductor", Vector3(1.4, 1.5, 3.4), Vector3(0, 1.1, 1.8)],
	]
	for frame in 30:
		await process_frame
	for k in views.size():
		var v: Array = views[k]
		camera.look_at_from_position(v[1], v[2])
		for frame in int(gap * 60):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("%s.png" % v[0]))
		print("shot ", v[0], " lead=", Groove.lead, " beat=", snappedf(Groove.beat, 0.01), " energy=", snappedf(Groove.energy, 0.01))
	quit()
