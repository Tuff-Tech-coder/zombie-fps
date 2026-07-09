extends Node
## Run-state snapshot (DESIGN_DOC §8.1). v0.2.0 stub: the fields exist so
## other systems can read them, but nothing writes them until the
## RoundManager arrives in v0.4.0.

enum Phase { PREP, ROUND }

var current_map := ""
var round_number := 0
var phase := Phase.PREP
var player_alive := true
