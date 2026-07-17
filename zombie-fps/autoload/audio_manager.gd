extends Node
## Music director + audio-bus owner (audio pass; phase-driven pools since
## v0.8.3). Owns a FIXED set of players — two crossfading music players and
## one dedicated stinger channel, all on the Music bus — and always
## stop/replaces through them. RULE: AudioManager never spawns ad-hoc
## players that outlive their purpose; every future one-shot gets its own
## dedicated, reused channel here.
##
## Regular music is phase-driven (EventBus): level load starts the
## prep_tracks rotation, round_started crossfades to the round_tracks
## rotation, round_cleared crossfades back. Within the active pool a
## shuffle-bag rotates songs (no immediate repeats, next pick whenever a
## song ends). Pool switches go through the two-player crossfade, so the
## outgoing track always STOPS — never layers — and re-entering the active
## pool never restarts the current song. An empty pool = silence, no error.
## boss_round_started -> MapMusic.boss_track (the one dedicated song, looped
## as a single-track pool); map_cleared (boss down) -> back to prep.
##
## Bus layout (default_bus_layout.tres): Master <- Music, Master <- SFX.
## Every world/weapon/enemy player routes to SFX (use SFX_BUS, never a bare
## string); only the players here live on Music.

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SILENCE_DB := -60.0
const DEATH_FADE := 1.5     ## seconds; player_died fades music out over this

var _soundtrack: MapMusic
var _players: Array[AudioStreamPlayer] = []
var _stinger: AudioStreamPlayer
var _fades: Array[Tween] = [null, null]
var _active := 0            ## which music player currently carries the music
var _current: AudioStream   ## dedupe: re-requesting the playing track is a no-op
var _pool: Array[AudioStream] = []  ## the phase pool currently rotating
var _bag: Array[AudioStream] = []   ## shuffle-bag drawn from _pool
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
	_stinger = AudioStreamPlayer.new()
	_stinger.name = "StingerPlayer"
	_stinger.bus = MUSIC_BUS
	add_child(_stinger)
	EventBus.round_started.connect(_on_round_started)
	EventBus.round_cleared.connect(_on_round_cleared)
	EventBus.boss_round_started.connect(_on_boss_round_started)
	EventBus.map_cleared.connect(_on_map_cleared)
	EventBus.player_died.connect(_on_player_died)


## Level roots call this on load — and again after the game-over scene
## reload, which is why it also silences the death stinger: the old run's
## death song must never bleed into the new run.
func set_soundtrack(soundtrack: MapMusic) -> void:
	_stinger.stop()
	_soundtrack = soundtrack
	_current = null
	# Fresh typed array, NOT clear() — _pool aliases the MapMusic resource's
	# own array, which must never be mutated from here.
	_pool = [] as Array[AudioStream]
	if _soundtrack != null:
		_enter_pool(_soundtrack.prep_tracks)
	else:
		_crossfade_to(null)


func _on_round_started(_round_number: int) -> void:
	if _soundtrack != null:
		_enter_pool(_soundtrack.round_tracks)


func _on_round_cleared(_round_number: int) -> void:
	if _soundtrack != null:
		_enter_pool(_soundtrack.prep_tracks)


## The boss's ONE dedicated song, as a single-track pool: the shuffle-bag's
## pools-of-one rule makes it restart on finished, i.e. it loops for the
## whole fight without needing the import loop flag.
func _on_boss_round_started() -> void:
	if _soundtrack != null and _soundtrack.boss_track != null:
		_enter_pool([_soundtrack.boss_track] as Array[AudioStream])
	else:
		_enter_pool([] as Array[AudioStream])  # no boss song authored = silence


## Boss down: back to the prep rotation as the victory lap (a dedicated
## victory cue can slot in here later without touching callers).
func _on_map_cleared() -> void:
	if _soundtrack != null:
		_enter_pool(_soundtrack.prep_tracks)


## Switch the rotation to a phase's pool. Re-entering the pool that is
## already playing keeps the current song running untouched.
func _enter_pool(pool: Array[AudioStream]) -> void:
	if pool == _pool and _current != null:
		return
	_pool = pool
	_bag.clear()
	_play_next_random()


func _play_next_random() -> void:
	if _pool.is_empty():
		_crossfade_to(null)
		return
	if _bag.is_empty():
		_bag = _pool.duplicate()
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
		# Dedicated channel, stop-before-play: a second death REPLACES the
		# death song, it never layers a new player on top.
		_stinger.stop()
		_stinger.stream = _soundtrack.death_stinger
		_stinger.play()


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
