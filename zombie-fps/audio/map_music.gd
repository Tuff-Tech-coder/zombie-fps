class_name MapMusic
extends Resource
## Per-map soundtrack contract (audio pass; rotation since v0.8.2): EVERY map
## authors one of these as a .tres under resources/audio/ and assigns it on
## its Level root — AudioManager stays completely map-agnostic. Regular play
## (prep AND rounds alike) draws random tracks from the `tracks` pool with no
## immediate repeats, rolling to the next pick whenever a song ends; only the
## boss gets one dedicated song. An empty pool means silence, by design.
##
## Pool tracks must NOT have the import loop flag set — rotation relies on
## the player's `finished` signal, which a looping stream never emits.

@export var tracks: Array[AudioStream] = []  ## rotation pool: prep + rounds
@export var boss_track: AudioStream          ## dedicated — RESERVED v0.9.0 boss hook
@export var death_stinger: AudioStream       ## optional one-shot as the player dies
@export_range(0.1, 10.0) var crossfade_time := 2.0  ## seconds between rotations
