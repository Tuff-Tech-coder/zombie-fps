class_name MapMusic
extends Resource
## Per-map soundtrack contract (audio pass): EVERY map authors one of these
## as a .tres under resources/audio/ and assigns it on its Level root —
## AudioManager stays completely map-agnostic, so adding a map's music is
## authoring data, never editing the manager. An unassigned track means
## silence for that phase, by design (no error, no fallback).

@export var prep_track: AudioStream      ## level load / free-fire / between rounds
@export var combat_track: AudioStream    ## while a round is live
@export var boss_track: AudioStream      ## RESERVED — v0.9.0 boss/victory hook
@export var death_stinger: AudioStream   ## optional one-shot as the player dies
@export_range(0.1, 10.0) var crossfade_time := 2.0  ## seconds, prep <-> combat
