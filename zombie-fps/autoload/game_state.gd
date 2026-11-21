extends Node
## Run-state snapshot (DESIGN_DOC §8.1). RoundManager is the sole writer of
## round_number and phase (since v0.4.0). player_alive remains a stub until
## something needs to read it.

enum Phase { PREP, ROUND }

var current_map := ""
var round_number := 0
var phase := Phase.PREP
var player_alive := true
