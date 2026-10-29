class_name DemoSynthAudio
extends Node

var player: AudioStreamPlayer
var samples: Dictionary = {}
var enabled := true

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.max_polyphony = 8
	player.volume_db = -18.0
	add_child(player)
	for kind in ["select", "clash", "strike", "guard", "victory", "defeat"]:
		samples[kind] = _make_sound(kind)

func play_sound(kind: String) -> void:
	if not enabled or not samples.has(kind):
		return
	player.stream = samples[kind]
	player.play()

func _make_sound(kind: String) -> AudioStreamWAV:
	var length := 0.16
	if kind == "victory" or kind == "defeat":
		length = 0.9
	var frequency := 520.0
	if kind == "clash": frequency = 980.0
	if kind == "strike": frequency = 120.0
	if kind == "guard": frequency = 430.0
	var sample_rate := 22050
	var data := PackedByteArray()
	data.resize(int(sample_rate * length) * 2)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 412
	for i in int(data.size() / 2):
		var t := float(i) / sample_rate
		var envelope := exp(-t * (28.0 if length < 0.5 else 4.5)) * minf(t * 700.0, 1.0)
		var wave := sin(TAU * frequency * t)
		if kind == "clash":
			wave = wave * 0.35 + sin(TAU * frequency * 1.47 * t) * 0.3 + noise_rng.randf_range(-0.35, 0.35)
		elif kind == "strike":
			wave = sin(TAU * (frequency * t - 55.0 * t * t)) * 0.6 + noise_rng.randf_range(-0.3, 0.3)
		elif kind == "victory":
			var note: float = [440.0, 554.37, 659.25][mini(2, int(t * 5.0))]
			wave = sin(TAU * note * t) * 0.5 + sin(TAU * note * 2 * t) * 0.15
		elif kind == "defeat":
			wave = sin(TAU * (220 * t - 70 * t * t)) * 0.5
		data.encode_s16(i * 2, int(clampf(wave * envelope, -1.0, 1.0) * 20000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
