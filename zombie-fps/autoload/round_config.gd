class_name RoundConfig
extends Resource
## Per-map round tuning (DESIGN_DOC §4 data-driven rule): a new map is a new
## .tres under resources/rounds/, not code. Consumed by RoundManager.

@export var starting_budget := 6    ## enemies in round 1
@export var budget_growth := 4      ## extra enemies per subsequent round
## Alive at once. Real maps target ~24–40 (DESIGN_DOC §3); never exceed the
## EnemyPool ceiling of 50.
@export var max_concurrent := 24
@export var spawn_interval := 0.8   ## seconds between spawn attempts
@export var prep_duration := 10.0   ## seconds of PREP between rounds
@export var rounds_per_map := 5     ## boss hand-off after this many (v0.9.0)


func budget_for(round_number: int) -> int:
	return starting_budget + budget_growth * (round_number - 1)
