extends Node
## Audio foundation (autoload "AudioLib").
##
## - Builds the reverb-carrying "SFX" bus at startup (done in code rather than a
##   default_bus_layout.tres so there's no resource file to keep in sync).
## - Loads sound assets by base name from res://audio/, accepting .ogg OR .wav,
##   each guarded by ResourceLoader.exists() so a MISSING file never breaks the
##   run. Missing footstep/hunter sounds fall back to a simple procedural tone so
##   the game is audible before real assets land; anything else returns null and
##   the caller just skips it.

const DIR := "res://audio/"

# Damp-tunnel reverb tuning (wet and roomy).
const REVERB_ROOM := 0.8
const REVERB_DAMP := 0.4
const REVERB_WET := 0.35
const REVERB_DRY := 0.85


func _ready() -> void:
	_ensure_sfx_bus()


func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index("SFX") != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "SFX")
	AudioServer.set_bus_send(idx, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = REVERB_ROOM
	reverb.damping = REVERB_DAMP
	reverb.wet = REVERB_WET
	reverb.dry = REVERB_DRY
	AudioServer.add_bus_effect(idx, reverb)


## Load res://audio/<base>.ogg or .wav. `looping` enables loop on the stream.
## Returns null (caller skips) when there's no file and no placeholder.
func load_stream(base: String, looping := false) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		var path: String = DIR + base + ext
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				_apply_loop(res, looping)
				return res
	return _placeholder(base, looping)


func _apply_loop(s: AudioStream, looping: bool) -> void:
	if not looping:
		return
	if s is AudioStreamOggVorbis or s is AudioStreamMP3:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		var frame_bytes := (2 if s.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if s.stereo else 1)
		if frame_bytes > 0:
			s.loop_end = s.data.size() / frame_bytes - 1


# --- Procedural placeholders (footsteps + hunter only; others stay silent) ---

func _placeholder(base: String, _looping: bool) -> AudioStream:
	match base:
		"footstep_walk":
			return _tone(140.0, 0.10, false, 0.5, 0.5)
		"footstep_sprint":
			return _tone(175.0, 0.09, false, 0.7, 0.5)
		"footstep_crouch":
			return _tone(110.0, 0.08, false, 0.3, 0.4)
		"land":
			return _tone(80.0, 0.20, false, 0.85, 0.3)
		"hunter_idle":
			return _tone(64.0, 2.0, true, 0.5, 0.2)   # 128 whole cycles -> seamless
		"hunter_move":
			return _tone(120.0, 0.5, true, 0.5, 0.7)  # 60 whole cycles -> seamless
		"hunter_alert":
			return _tone(220.0, 0.4, false, 0.8, 0.1, 540.0)
	return null


## Build a tiny mono 16-bit tone. `noise_amt` blends in white noise; `sweep_to`
## (>0) glides the pitch; loops play steady, one-shots decay quickly.
func _tone(freq: float, dur: float, looping: bool, vol: float,
		noise_amt := 0.0, sweep_to := 0.0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / rate
		var prog := t / dur
		var f := freq if sweep_to <= 0.0 else lerpf(freq, sweep_to, prog)
		var env := 1.0 if looping else exp(-prog * 5.0)
		var v := sin(TAU * f * t)
		if noise_amt > 0.0:
			v = lerpf(v, randf() * 2.0 - 1.0, noise_amt)
		v *= env * vol
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	if looping:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n - 1
	return s
