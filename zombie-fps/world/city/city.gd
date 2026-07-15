extends Node3D
## First full map — WW2 British city, pre-bombing (v0.8.0). A new map is new
## data (CODE_GUIDE): this root only assigns the city's round + director
## .tres to the autoload managers at load. Rounds still start via the debug
## WAVE button; real map-flow start lands with the boss milestone (v0.9.0).

const ROUNDS: RoundConfig = preload("res://resources/rounds/city_rounds.tres")
const DIRECTOR: DirectorConfig = preload("res://resources/config/city_director.tres")


func _enter_tree() -> void:
	RoundManager.config = ROUNDS
	SpawnDirector.config = DIRECTOR
