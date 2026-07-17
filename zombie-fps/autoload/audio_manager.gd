extends Node
## Music director + audio-bus owner (audio pass, off-roadmap patch).
## Owns two AudioStreamPlayers on the Music bus and crossfades them as the
## game phase changes (EventBus-driven, signals-first). Completely
## map-agnostic: every map's Level root hands its own MapMusic .tres to
## set_soundtrack() — adding a map's music is authoring data, never editing
## this file. An unassigned track for a phase means silence, no error.
##
## Bus layout (default_bus_layout.tres): Master <- Music, Master <- SFX.
## Every world/weapon/enemy player routes to SFX (use SFX_BUS, never a bare
## string); only the two players here live on Music.

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SILENCE_DB := -60.0
const DEATH_FADE := 1.5     ## seconds; player_died fades music out over this

var _soundtrack: MapMusic
var _players: Array[AudioStreamPlayer] = []
var _fades: Array[Tween] = [null, null]
var _active := 0            ## which player currently carries the music
var _current: AudioStream   ## dedupe: re-requesting the playing track is a no-op


func _ready() -> void:
	# The death fade/stinger must run while game_over pauses the tree.
	process_mode = PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "MusicPlayer%d" % (i + 1)
		p.bus = MUSIC_BUS
		p.volume_db = SILENCE_DB
		add_child(p)
		_players.append(p)
	EventBus.round_started.connect(_on_round_started)
	EventBus.round_cleared.connect(_on_round_cleared)
	EventBus.player_died.connect(_on_player_died)
	# EventBus.map_cleared -> boss/victory cue: RESERVED seam for v0.9.0
	# (MapMusic.boss_track exists; nothing consumes it yet by design).


## Level roots call this on load. Starts the prep/ambient track — also the
## free-fire default before any round has ever started.
func set_soundtrack(soundtrack: MapMusic) -> void:
	_soundtrack = soundtrack
	_current = null
	_crossfade_to(_soundtrack.prep_track if _soundtrack else null)


func _on_round_started(_round_number: int) -> void:
	_crossfade_to(_soundtrack.combat_track if _soundtrack else null)


func _on_round_cleared(_round_number: int) -> void:
	_crossfade_to(_soundtrack.prep_track if _soundtrack else null)


func _on_player_died() -> void:
	_current = null
	for p in _players:
		_fade(p, SILENCE_DB, DEATH_FADE, true)
	if _soundtrack != null and _soundtrack.death_stinger != null:
		var stinger := AudioStreamPlayer.new()
		stinger.bus = MUSIC_BUS
		stinger.stream = _soundtrack.death_stinger
		add_child(stinger)
		stinger.finished.connect(stinger.queue_free)
		stinger.play()


func _crossfade_to(stream: AudioStream) -> void:
	if stream == _current:
		return
	var time: float = _soundtrack.crossfade_time if _soundtrack != null else 2.0
	_current = stream
	_fade(_players[_active], SILENCE_DB, time, true)
	if stream == null:
		return  # unassigned phase track = silence, by design
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.volume_db = SILENCE_DB
	p.play()
	_fade(p, 0.0, time, false)


func _fade(player: AudioStreamPlayer, to_db: float, time: float, stop_after: bool) -> void:
	var idx := _players.find(player)
	if idx >= 0 and _fades[idx] != null and _fades[idx].is_valid():
		_fades[idx].kill()
	var tween := create_tween()
	if idx >= 0:
		_fades[idx] = tween
	tween.tween_property(player, "volume_db", to_db, time)
	if stop_after:
		tween.tween_callback(player.stop)
