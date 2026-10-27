extends SceneTree
## Brings song files (or every song in a folder) aboard from the command line, as the desk's
## + Add songs does: each is listened to with ffmpeg and kept, with its beat map, in user://songs.
##   godot --headless --path . --script tools/add_songs.gd -- <song or folder>...


func _initialize() -> void:
	var import := SongImport.new()
	for given in OS.get_cmdline_user_args():
		var paths := []
		if DirAccess.dir_exists_absolute(given):
			for file in DirAccess.get_files_at(given):
				if file.get_extension().to_lower() in SongImport.OPENS:
					paths.append(given.path_join(file))
		else:
			paths.append(given)
		for path: String in paths:
			var result := import._add_file(path)
			if result.begins_with("!"):
				printerr(result.substr(1))
			else:
				var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SongImport.DIR.path_join(result.get_basename() + ".beats.json")))
				print("ADDED %s: %s, %.1f s, %.1f bpm, %d/4 from beat %d, %d beats, onsets %s" % [result, data.title, data.seconds, data.bpm,
						data.meter, data.first_downbeat, data.beats.size(), str(data.onsets.map(func(o: Array) -> int: return o.size()))])
	import.free()
	quit()
