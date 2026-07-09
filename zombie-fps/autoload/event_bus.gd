extends Node
## Global signal hub (DESIGN_DOC §8.3). Systems emit here, listeners connect
## here. No gameplay logic in this file, ever — it stays a pure declaration
## so nothing can accidentally couple through it.

# Every signal here is emitted/consumed by *other* scripts, so the
# unused-signal warning is noise for this file.
@warning_ignore_start("unused_signal")

# -- player / weapons / HUD (live since v0.2.0) --
signal player_health_changed(current: float, max_health: float)
signal weapon_equipped(data: WeaponData)
signal weapon_fired(weapon: Weapon)
signal ammo_changed(mag: int, reserve: int)
signal weapon_reload_started(duration: float)
signal weapon_reload_finished()

# -- declared ahead of their milestones so downstream briefs slot in --
signal enemy_died(enemy)                       # v0.3.0
signal round_started(round_number: int)        # v0.4.0
signal round_cleared(round_number: int)        # v0.4.0
signal resource_picked_up(resource)            # v0.5.0
signal perk_crafted(perk)                      # v0.6.0
