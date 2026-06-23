extends Node
## Global noise bus (autoload "NoiseBus").
##
## Named "NoiseBus" rather than "Noise" because Godot already ships a built-in
## `Noise` class (base of FastNoiseLite); an autoload called "Noise" would be
## shadowed by it in scripts.
##
## Anything that makes a sound calls NoiseBus.emit_noise(position, radius). Listeners
## (the hunter today) decide for themselves whether they're close enough to hear
## it — the bus doesn't know or care who's listening. This keeps sound a
## first-class, decoupled signal that items/traps/etc. can use later.

## position: where the sound happened. radius: how far away it can be heard.
signal noise_made(position: Vector3, radius: float)


func emit_noise(position: Vector3, radius: float) -> void:
	noise_made.emit(position, radius)
