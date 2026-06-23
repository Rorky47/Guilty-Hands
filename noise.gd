extends Node
## Global sound field (autoload "NoiseBus").
##
## Sounds are no longer one-shot pings: each emit_noise() drops a CLUE into a
## field of DECAYING clues. A clue's strength fades to zero over clue_lifetime.
## Listeners (the hunter) read the live field via get_clues() and pursue the
## freshest/loudest, so a moving player lays a trail that gets continuously
## chased rather than heard once and forgotten.
##
## The field knows nothing about the player — only where and how loud sounds
## were. (Named "NoiseBus", not "Noise", to avoid Godot's built-in Noise class.)

## Still emitted on each sound, for anything that wants the raw edge event.
signal noise_made(position: Vector3, strength: float)

## Seconds for a clue to decay fully to zero.
@export var clue_lifetime: float = 6.0
## Hard cap on stored clues (oldest dropped first).
@export var max_clues: int = 64


class Clue:
	var position: Vector3
	var strength: float                 # strength at birth (the old "radius" value)
	var born: float                     # monotonic seconds when emitted
	var current_strength: float = 0.0   # decayed value, filled in by get_clues()


var _clues: Array[Clue] = []


## Drop a sound clue into the field. `strength` is the old noise-radius value.
func emit_noise(position: Vector3, strength: float) -> void:
	var c := Clue.new()
	c.position = position
	c.strength = strength
	c.born = _now()
	_clues.append(c)
	if _clues.size() > max_clues:
		_clues = _clues.slice(_clues.size() - max_clues)
	noise_made.emit(position, strength)


## Live clues, each with current_strength set to its decayed value; fully decayed
## clues are pruned. Decay = strength * clamp(1 - age / clue_lifetime, 0, 1).
func get_clues() -> Array[Clue]:
	var now := _now()
	var live: Array[Clue] = []
	for c in _clues:
		var age := now - c.born
		var cs := c.strength * clampf(1.0 - age / clue_lifetime, 0.0, 1.0)
		if cs > 0.0:
			c.current_strength = cs
			live.append(c)
	_clues = live
	return live


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
