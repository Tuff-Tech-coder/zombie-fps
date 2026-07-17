class_name MapMusic
extends Resource
## Per-map soundtrack contract (audio pass; phase-driven pools since v0.8.3):
## EVERY map authors one of these as a .tres under resources/audio/ and
## assigns it on its Level root — AudioManager stays completely map-agnostic.
## Each phase owns a rotation POOL: AudioManager shuffle-bags the active
## pool (no immediate repeats, next pick whenever a song ends) and
## crossfades between pools on round transitions. An empty pool means
## silence for that phase, by design — leave prep_tracks empty for maps
## that should stay quiet until a round starts.
##
## Pool tracks must NOT have the import loop flag set — rotation relies on
## the player's `finished` signal, which a looping stream never emits.

@export var prep_tracks: Array[AudioStream] = []   ## level load + PREP + between rounds
@export var round_tracks: Array[AudioStream] = []  ## while a round is live
@export var boss_track: AudioStream                ## the boss round's ONE dedicated song (loops)
@export var death_stinger: AudioStream             ## one-shot as the player dies
@export_range(0.1, 10.0) var crossfade_time := 2.0  ## seconds, pool <-> pool
