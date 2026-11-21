class_name DemoSynthAudio
extends Node

const SOUND_KINDS := ["select", "clash", "strike", "heavy_strike", "guard", "coin_break", "skill", "victory", "defeat"]
const VICTORY_NOTES := [440.0, 554.37, 659.25]

static var samples: Dictionary = {}
var player: AudioStreamPlayer
var enabled := true

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.max_polyphony = 8
	player.volume_db = -12.0
	add_child(player)
	if samples.is_empty():
		for kind in SOUND_KINDS:
			var stream := _load_runtime_sound(kind)
			if stream == null:
				stream = _make_sound(kind)
			samples[kind] = stream

static func _load_runtime_sound(kind: String) -> AudioStream:
	var path_map := {
		"select": "res://runtime_assets/sfx/sfx_ui_select_card_a.wav",
		"clash": "res://runtime_assets/sfx/sfx_clash_metal_a.wav",
		"strike": "res://runtime_assets/sfx/sfx_hit_slash_a.wav",
		"heavy_strike": "res://runtime_assets/sfx/sfx_hit_flesh_a.wav",
		"guard": "res://runtime_assets/sfx/sfx_guard_block_a.wav",
		"coin_break": "res://runtime_assets/sfx/sfx_clash_coin_break_a.wav",
		"skill": "res://runtime_assets/sfx/sfx_skill_cast_a.wav",
		"victory": "res://runtime_assets/sfx/sfx_victory_a.wav",
		"defeat": "res://runtime_assets/sfx/sfx_defeat_a.wav"
	}
	if path_map.has(kind) and ResourceLoader.exists(path_map[kind]):
		return load(path_map[kind]) as AudioStream
	return null

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
	if kind == "heavy_strike": frequency = 90.0
	if kind == "guard": frequency = 430.0
	if kind == "coin_break": frequency = 1250.0
	if kind == "skill": frequency = 780.0
	var sample_rate := 22050
	var data := PackedByteArray()
	data.resize(int(sample_rate * length) * 2)
	var decay := 28.0 if length < 0.5 else 4.5
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 412
	for i in int(data.size() / 2):
		var t := float(i) / sample_rate
		var envelope := exp(-t * decay) * minf(t * 700.0, 1.0)
		var wave := sin(TAU * frequency * t)
		if kind == "clash":
			wave = wave * 0.35 + sin(TAU * frequency * 1.47 * t) * 0.3 + noise_rng.randf_range(-0.35, 0.35)
		elif kind == "strike":
			wave = sin(TAU * (frequency * t - 55.0 * t * t)) * 0.6 + noise_rng.randf_range(-0.3, 0.3)
		elif kind == "victory":
			var note: float = VICTORY_NOTES[mini(2, int(t * 5.0))]
			wave = sin(TAU * note * t) * 0.5 + sin(TAU * note * 2 * t) * 0.15
		elif kind == "defeat":
			wave = sin(TAU * (220 * t - 70 * t * t)) * 0.5
		data.encode_s16(i * 2, int(clampf(wave * envelope, -1.0, 1.0) * 20000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
