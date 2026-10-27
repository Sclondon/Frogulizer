extends SceneTree
## The camera desk on a phone: laid out at the phone's size, one finger turns the orbit round,
## two pinch it in and out, and a take copied as text comes back the same. Ends PASSED or FAILED.
##   godot --path . --audio-driver Dummy --resolution 390x844 --script tests/touch.gd

var failed := []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for frame in 30:
		await process_frame
	var desk: CameraDesk = main.desk
	_check(desk._phone, "the desk is laid out for a phone")
	_check(desk._panel.get_global_rect().position.y >= root.get_visible_rect().size.y * 0.45, "the panel is under the picture")
	_check(desk._bar.get_global_rect().end.x <= root.get_visible_rect().size.x + 1.0, "the bar fits across the screen")
	desk.show_panel(false)
	desk._set_mode("orbit")
	await process_frame
	# One finger across the picture (a drag only, as an iPhone can send it: no finger going down)
	var yaw: float = desk._orbit_yaw
	for k in 10:
		_send_drag(0, Vector2(100 + k * 12, 300), Vector2(12, 0))
		await process_frame
	_touch(0, Vector2(220, 300), false)
	_check(absf(desk._orbit_yaw - yaw) > 0.2, "a drag turns the orbit round (%.2f to %.2f)" % [yaw, desk._orbit_yaw])
	# Two fingers spread apart: in closer
	var distance: float = desk._orbit_distance
	_touch(0, Vector2(150, 300), true)
	_touch(1, Vector2(250, 300), true)
	for k in 8:
		_send_drag(0, Vector2(150 - k * 8, 300), Vector2(-8, 0))
		_send_drag(1, Vector2(250 + k * 8, 300), Vector2(8, 0))
		await process_frame
	_touch(0, Vector2(86, 300), false)
	_touch(1, Vector2(314, 300), false)
	_check(desk._orbit_distance < distance * 0.75, "a pinch out brings it in (%.1f to %.1f)" % [distance, desk._orbit_distance])
	# A take as text and back
	desk.keys = [desk._camera_key()]
	desk.keys[0]["time"] = 0.0
	desk.focal = 50.0
	var text := JSON.stringify(desk._take())
	desk.keys = []
	desk.focal = 28.0
	desk._use_take(JSON.parse_string(text))
	_check(desk.keys.size() == 1 and is_equal_approx(desk.focal, 50.0), "a copied take comes back with its keys and lens")
	print("FAILED: " + ", ".join(failed) if not failed.is_empty() else "PASSED")
	quit(1 if not failed.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failed.append(what)


# (touches arrive in window pixels: mapped from the view's, as the stretch has it)
func _touch(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * at
	event.pressed = down
	Input.parse_input_event(event)


func _send_drag(index: int, at: Vector2, move: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = root.get_final_transform() * at
	event.relative = root.get_final_transform().basis_xform(move)
	Input.parse_input_event(event)
