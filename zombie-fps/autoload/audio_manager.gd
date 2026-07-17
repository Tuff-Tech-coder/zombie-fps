extends Node
## Music director + audio-bus owner (audio pass; rotation since v0.8.2).
## Owns two AudioStreamPlayers on the Music bus. Regular play — prep and
## rounds alike — rotates through the map's randomized track pool
## (shuffle-bag, no immediate repeats, next pick whenever a song ends);
## only the boss gets a dedicated song (RESERVED v0.9.0 seam). Completely
## map-agnostic: every map's Level root hands its own MapMusic here —
## adding a map's music is authoring data, never editing this file.
## An empty pool means silence, no error.
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
var _bag: Array[AudioStream] = []  ## shuffle-bag for the rotation pool
var _last_track: AudioStream


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
		p.finished.connect(_on_track_finished.bind(p))
	EventBus.player_died.connect(_on_player_died)
	# round_started/round_cleared are deliberately NOT consumed since v0.8.2:
	# regular play rotates one randomized pool across prep AND rounds.
	# EventBus.map_cleared -> MapMusic.boss_track: RESERVED seam for v0.9.0.


## Level roots call this on load. Starts the rotation (also restarts it after
## the game-over scene reload).
func set_soundtrack(soundtrack: MapMusic) -> void:
	_soundtrack = soundtrack
	_current = null
	_bag.clear()
	_play_next_random()


func _play_next_random() -> void:
	if _soundtrack == null or _soundtrack.tracks.is_empty():
		_crossfade_to(null)
		return
	if _bag.is_empty():
		_bag = _soundtrack.tracks.duplicate()
		_bag.shuffle()
		# A fresh bag must not open with the song that just played
		# (pools of one legitimately repeat — that's a looping soundtrack).
		if _bag.size() > 1 and _bag[0] == _last_track:
			_bag.push_back(_bag.pop_front())
	var next: AudioStream = _bag.pop_front()
	_last_track = next
	_crossfade_to(next)


## Rotation trigger: a song the active player carried ran to its natural end.
## Faded-out crossfade partners and post-death silence (_current == null)
## never rotate.
func _on_track_finished(player: AudioStreamPlayer) -> void:
	if player != _players[_active] or _current == null:
		return
	_current = null  # the track is over; don't dedupe the next pick against it
	_play_next_random()


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
		return  # empty pool = silence, by design
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
