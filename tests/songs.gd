extends SceneTree
## Bringing a song aboard as the desk's + Add songs does (on the computer: ffmpeg listens to it, on a
## thread), playing it, and taking it off again. Needs a song aboard already (any) to copy from.
## Ends PASSED or FAILED.
##   godot --path . --audio-driver Dummy --resolution 390x844 --script tests/songs.gd

var failed := []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for frame in 20:
		await process_frame
	var desk: CameraDesk = main.desk
	var player: TrackPlayer = main.player
	_check(not player.tracks.is_empty(), "the songs aboard are listed (%d)" % player.tracks.size())
	_check(desk._songs.item_count == player.tracks.size(), "and on the desk")
	# A song from somewhere else on the computer, under a name not aboard
	var source := ProjectSettings.globalize_path(SongImport.DIR.path_join(player.tracks[0].song))
	var copy := OS.get_cache_dir().path_join("Frog Test Band - A Test Song." + source.get_extension())
	DirAccess.copy_absolute(source, copy)
	var count := player.tracks.size()
	var added := []
	desk._song_import.added.connect(func(name: String) -> void: added.append(name))
	desk._song_import.add_files([copy])
	var waited := 0
	while added.is_empty() and waited < 600:
		await process_frame
		waited += 1
	_check(added.size() == 1, "the song is brought aboard (%s)" % desk._status.text)
	var at := player.find(added[0] if not added.is_empty() else "")
	_check(at >= 0 and player.tracks.size() == count + 1, "it is in the list")
	if at >= 0:
		_check(player.tracks[at].title == "A Test Song" and player.tracks[at].artist == "Frog Test Band", "its title and band from its name")
		player.play(at)
		for frame in 10:
			await process_frame
		_check(player.playing and player.index == at, "it plays")
		desk._songs.select(at)
		desk._remove_song()
		_check(player.find(added[0]) < 0 and not FileAccess.file_exists(SongImport.DIR.path_join(added[0])), "and is taken off again")
	DirAccess.remove_absolute(copy)
	print("FAILED: " + ", ".join(failed) if not failed.is_empty() else "PASSED")
	quit(1 if not failed.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failed.append(what)
