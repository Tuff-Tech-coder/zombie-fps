class_name DebugDoor
extends AnimatableBody3D
## Debug fixture: a door that slides into the floor. The navmesh is baked with
## the opening walkable, so a closed door blocks bodies physically but not
## paths — fine for a test fixture, revisit if real maps need dynamic doors.

@export var slide_distance := 3.05
@export var slide_time := 1.1

var _open := false
var _closed_y := 0.0
var _tween: Tween


func _ready() -> void:
	_closed_y = position.y


## Returns the new open state (the debug button uses it for its lamp).
func toggle() -> bool:
	_open = not _open
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var target_y := _closed_y - slide_distance if _open else _closed_y
	_tween.tween_property(self, "position:y", target_y, slide_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return _open
