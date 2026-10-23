extends Node
## Procedural sound bank: every effect is synthesised at startup, so the game
## has punchy audio with zero asset files. Replace an entry in _streams with a
## loaded .ogg/.wav later and every call site keeps working.

const MIX_RATE := 22050
const VOICES := 14

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	#                               len   f0     f1    noise decay smooth
	_streams[&"whoosh"] = _synth(0.13, 500.0, 180.0, 0.95, 4.0, 0.12)
	_streams[&"hit_light"] = _synth(0.13, 230.0, 70.0, 0.55, 7.0, 0.45)
	_streams[&"hit_heavy"] = _synth(0.32, 170.0, 38.0, 0.6, 5.0, 0.3)
	_streams[&"block"] = _synth(0.1, 950.0, 620.0, 0.35, 10.0, 0.6)
	_streams[&"parry"] = _synth(0.5, 1560.0, 1480.0, 0.03, 5.0, 0.9)
	_streams[&"ko"] = _synth(0.9, 120.0, 28.0, 0.5, 3.2, 0.22)
	_streams[&"land"] = _synth(0.08, 130.0, 60.0, 0.85, 8.0, 0.2)
	_streams[&"jump"] = _synth(0.1, 260.0, 520.0, 0.4, 6.0, 0.3)
	_streams[&"ui"] = _synth(0.06, 880.0, 1320.0, 0.05, 6.0, 0.8)
	_streams[&"gong"] = _synth(1.1, 196.0, 190.0, 0.08, 2.4, 0.7)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(id: StringName, pitch := 1.0, volume_db := 0.0) -> void:
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch * randf_range(0.94, 1.06)
	player.volume_db = volume_db
	player.play()


## A pitched sine sweep mixed with noise, low-passed and given a fast attack
## plus exponential decay. Enough to cover whooshes, thuds, clangs and rings.
func _synth(duration: float, f0: float, f1: float, noise: float, decay: float, smooth: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var filtered := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var k := t / duration
		phase += TAU * lerpf(f0, f1, k) / MIX_RATE
		var raw := sin(phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		filtered = lerpf(filtered, raw, smooth)
		var envelope := exp(-k * decay) * minf(1.0, t * 500.0)
		data.encode_s16(i * 2, int(clampf(filtered * envelope * 0.85, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
