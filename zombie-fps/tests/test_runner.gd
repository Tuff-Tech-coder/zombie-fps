extends Node
## Headless smoke suite. Run as a scene so the autoloads exist:
##   godot --headless --path zombie-fps res://tests/test_runner.tscn
## Prints one summary line (plus any failures); exit code 1 on failure.

var _passed := 0
var _failures: Array[String] = []


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failures.append(what)


func _ready() -> void:
	_test_no_unlicensed_binaries()
	_test_scenes_load()
	_test_soundtracks()
	_test_enemy_clips()
	await _test_round_flow()
	_finish()


## License hygiene (CLAUDE.md): no Mixamo FBX / ripped mp3 in the project.
func _test_no_unlicensed_binaries() -> void:
	var bad: Array[String] = []
	_scan("res://", bad)
	_check(bad.is_empty(), "unlicensed binary types present: %s" % [bad])


func _scan(dir: String, bad: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in ["fbx", "mp3"]:
			bad.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d != "addons":
			_scan(dir.path_join(d), bad)


func _test_scenes_load() -> void:
	for path in [
		"res://enemies/zombie_walker.tscn",
		"res://enemies/pumpkin_boss.tscn",
		"res://world/city/city.tscn",
		"res://world/greybox.tscn",
	]:
		var scene := load(path) as PackedScene
		_check(scene != null, "%s loads" % path)
		if scene != null:
			var node := scene.instantiate()
			_check(node != null, "%s instantiates" % path)
			if node != null:
				node.free()


func _test_soundtracks() -> void:
	for path in ["res://resources/audio/city_soundtrack.tres", "res://resources/audio/greybox_soundtrack.tres"]:
		var music := load(path) as MapMusic
		_check(music != null, "%s loads" % path)
		if music == null:
			continue
		var streams: Array = []
		streams.append_array(music.prep_tracks)
		streams.append_array(music.round_tracks)
		streams.append(music.boss_track)
		streams.append(music.death_stinger)
		for s in streams:
			_check(s != null and s.get_length() > 0.0, "%s has a non-empty stream" % path)


func _test_enemy_clips() -> void:
	for path in ["res://enemies/zombie_walker.tscn", "res://enemies/pumpkin_boss.tscn"]:
		var enemy := (load(path) as PackedScene).instantiate()
		var visual: EnemyVisual = enemy.get_node("Visual")
		var player: AnimationPlayer = visual.get_node("Model").find_child("AnimationPlayer", true, false)
		for clip in [visual.locomotion_clip, visual.attack_clip, visual.death_clip]:
			_check(player != null and player.has_animation(clip), "%s has clip %s" % [path, clip])
		enemy.free()


## The debug WAVE button's code path: a run starts and zombies spawn; then the
## boss spawns and dies. Kept under ~6 s: an unattended player dies at ~8 s.
func _test_round_flow() -> void:
	add_child((load("res://world/city/city.tscn") as PackedScene).instantiate())
	await get_tree().create_timer(1.5).timeout
	DebugManager.toggle_wave_stub()
	_check(RoundManager.running, "wave button starts a run")
	RoundManager.skip_prep()
	await get_tree().create_timer(4.0).timeout
	_check(RoundManager.live_count() > 0, "zombies spawn once the wave starts")
	var boss: Enemy = EnemyPool.acquire(SpawnDirector.next_spawn_position(), load("res://enemies/pumpkin_boss.tscn"))
	_check(boss != null, "boss spawns")
	if boss != null:
		boss.take_damage(99999.0)
		_check(boss.state == Enemy.State.DEAD, "boss dies from lethal damage")


func _finish() -> void:
	var total := _passed + _failures.size()
	print("TESTS: %d/%d passed" % [_passed, total])
	for f in _failures:
		print("  FAIL: ", f)
	get_tree().quit(1 if not _failures.is_empty() else 0)
