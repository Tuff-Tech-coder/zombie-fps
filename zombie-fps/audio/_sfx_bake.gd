extends SceneTree
## One-shot generator for the placeholder audio assets (music loops, death
## stinger, enemy vocal set), mirroring world/city/textures/_texture_bake.gd:
## synth placeholders are generated in-engine and committed as .res, then
## replaced by real CC0 files (DESIGN_DOC §10) by swapping the .tres
## references — no code changes. Run headless:
##   godot --headless --path zombie-fps -s res://audio/_sfx_bake.gd

const MIX_RATE := 22050
const OUT_DIR := "res://resources/audio/generated/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	# Greybox pair: A-rooted (55 Hz) slow drone / 100 BPM combat pulse.
	_save("greybox_prep_loop", _render(12.0, _drone.bind(55.0)), true)
	_save("greybox_combat_loop", _render(9.6, _combat.bind(55.0, 100.0)), true)
	# City pair: D-rooted (73.4 Hz), faster — audibly a different soundtrack,
	# proving the per-map MapMusic contract.
	_save("city_prep_loop", _render(12.0, _drone.bind(73.4)), true)
	_save("city_combat_loop", _render(8.7, _combat.bind(73.4, 110.0)), true)
	_save("death_stinger", _render(1.8, _stinger), false)
	# Enemy vocal set (assigned as data on the enemy scenes).
	_save("zombie_groan", _render(1.1, _groan), false)
	_save("zombie_snarl", _render(0.5, _snarl), false)
	_save("zombie_gurgle", _render(1.3, _gurgle), false)
	print("SFX_BAKE_DONE")
	quit()


func _drone(t: float, rng: RandomNumberGenerator, root: float) -> float:
	var swell := 0.6 + 0.4 * sin(TAU * t / 12.0)          # slow breath
	var low := sin(TAU * root * t) * 0.28
	var fifth := sin(TAU * root * 1.5 * t + 0.7) * 0.14
	var wash := rng.randf_range(-1.0, 1.0) * 0.03 * (1.0 + sin(TAU * t / 6.0))
	return (low + fifth + wash) * swell


func _combat(t: float, rng: RandomNumberGenerator, root: float, bpm: float) -> float:
	var beat := 60.0 / bpm
	var bt := fmod(t, beat)
	var thump := sin(TAU * (root * 1.2) * bt) * exp(-bt * 14.0) * 0.55
	var bar := int(t / beat) % 4
	var bass_f: float = root if bar < 2 else root * 1.19    # minor-third turn
	var bass := signf(sin(TAU * bass_f * t)) * 0.09          # square growl
	var tick := rng.randf_range(-1.0, 1.0) * exp(-fmod(t + beat * 0.5, beat) * 40.0) * 0.12
	return thump + bass + tick


func _stinger(t: float, rng: RandomNumberGenerator) -> float:
	var fall := sin(TAU * (220.0 - t * 90.0) * t) * exp(-t * 2.2) * 0.5
	var burst := rng.randf_range(-1.0, 1.0) * exp(-t * 9.0) * 0.3
	return fall + burst


func _groan(t: float, rng: RandomNumberGenerator) -> float:
	var pitch := 82.0 - t * 14.0                             # sagging moan
	var voice := sin(TAU * pitch * t) * 0.4 + sin(TAU * pitch * 2.02 * t) * 0.18
	var breath := rng.randf_range(-1.0, 1.0) * 0.08
	var env := minf(t * 8.0, 1.0) * exp(-maxf(t - 0.55, 0.0) * 4.0)
	return (voice + breath) * env


func _snarl(t: float, rng: RandomNumberGenerator) -> float:
	var growl := signf(sin(TAU * (130.0 + t * 60.0) * t)) * 0.25
	var rasp := rng.randf_range(-1.0, 1.0) * 0.35
	return (growl + rasp) * exp(-t * 5.0) * minf(t * 30.0, 1.0)


func _gurgle(t: float, rng: RandomNumberGenerator) -> float:
	var pitch := 95.0 - t * 45.0
	var voice := sin(TAU * pitch * t + sin(TAU * 9.0 * t) * 2.0) * 0.4
	var rattle := rng.randf_range(-1.0, 1.0) * 0.12 * (1.0 + sin(TAU * 16.0 * t))
	return (voice + rattle) * exp(-t * 2.6)


func _render(duration: float, sample: Callable) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337  # deterministic, like PlaceholderSfx
	var count := int(duration * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var v: float = clampf(sample.call(float(i) / MIX_RATE, rng), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = bytes
	return stream


func _save(name: String, stream: AudioStreamWAV, loop: bool) -> void:
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size() / 2
	var err := ResourceSaver.save(stream, OUT_DIR + name + ".res")
	print("%s -> %s" % [name, error_string(err)])
