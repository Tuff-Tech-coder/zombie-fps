extends NavigationRegion3D
## Bakes the navmesh at load. The greybox is CSG that still changes every
## milestone, so a runtime bake beats maintaining a baked resource in the
## scene file. Only this node's children (the Geometry tree) are parsed —
## the door, targets, and panel live outside it on purpose.

func _ready() -> void:
	# CSG builds its meshes during the first process frames; bake after.
	await get_tree().process_frame
	await get_tree().process_frame
	bake_navigation_mesh()
