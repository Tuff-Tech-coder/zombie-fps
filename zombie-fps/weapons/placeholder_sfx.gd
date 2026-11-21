class_name PlaceholderSfx
## Synthesizes throwaway WAV blips at load time so v0.2.0 ships zero audio
## assets. Replaced wholesale when the real audio pass happens (post-greybox,
## DESIGN_DOC §10 sources).

const MIX_RATE := 22050


static func gunshot() -> AudioStreamWAV:
	return _render(0.22, _gunshot_sample)


static func impact() -> AudioStreamWAV:
	return _render(0.08, _impact_sample)


static func reload_click() -> AudioStreamWAV:
	return _render(0.1, _reload_sample)


static func dry_click() -> AudioStreamWAV:
	return _render(0.05, _dry_sample)


static func electric_buzz() -> AudioStreamWAV:
	var stream := _render(0.5, _buzz_sample)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(0.5 * MIX_RATE)
	return stream


static func _gunshot_sample(t: float, rng: RandomNumberGenerator) -> float:
	var noise := rng.randf_range(-1.0, 1.0) * exp(-t * 28.0)
	var thump := sin(TAU * 95.0 * t) * exp(-t * 18.0)
	return noise * 0.7 + thump * 0.5


static func _impact_sample(t: float, rng: RandomNumberGenerator) -> float:
	return rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.5


static func _reload_sample(t: float, rng: RandomNumberGenerator) -> float:
	return (rng.randf_range(-0.4, 0.4) + sin(TAU * 1400.0 * t) * 0.4) * exp(-t * 60.0)


static func _dry_sample(t: float, _rng: RandomNumberGenerator) -> float:
	return sin(TAU * 2200.0 * t) * exp(-t * 80.0) * 0.4


static func _buzz_sample(t: float, rng: RandomNumberGenerator) -> float:
	# Mains-style square hum with crackle riding on a slow wobble.
	var hum := signf(sin(TAU * 110.0 * t)) * 0.18
	var crackle := rng.randf_range(-1.0, 1.0) * 0.12 * (1.0 + sin(TAU * 13.0 * t)) * 0.5
	return hum + crackle


static func _render(duration: float, sample: Callable) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337  # deterministic: same placeholder sound every launch
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
