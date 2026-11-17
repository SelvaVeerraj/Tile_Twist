extends Node
## SoundManager (autoload) – plays short sound effects.
##
## All effects are synthesised at start-up into AudioStreamWAV resources, so
## the game ships with zero audio files and no licensing concerns.
## To use your own audio, drop a file named after the effect into
## res://assets/sounds/ (for example "win.wav" or "win.ogg") and it will be
## used instead of the synthesised version.

const MIX_RATE := 22050
const POOL_SIZE := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_library()


## Plays an effect by name. Respects the Sound ON/OFF setting.
func play(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not GameData.is_sound_on():
		return
	var stream: AudioStream = _streams.get(sound_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _players[_next]
		_next = (_next + 1) % POOL_SIZE
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


func _build_library() -> void:
	# Each entry: [notes, waveform, volume]
	# A note is [start_freq, end_freq, start_time, duration] (Hz / seconds).
	var defs := {
		"click": [[[880.0, 1180.0, 0.0, 0.045]], "sine", 0.32],
		"pick": [[[520.0, 820.0, 0.0, 0.08]], "triangle", 0.45],
		"drop": [[[360.0, 210.0, 0.0, 0.1]], "triangle", 0.5],
		"swap": [[[620.0, 880.0, 0.0, 0.06], [880.0, 1240.0, 0.05, 0.07]], "triangle", 0.4],
		"correct": [[[1046.5, 1046.5, 0.0, 0.14], [1318.5, 1318.5, 0.07, 0.24]], "bell", 0.38],
		"combo": [[[784.0, 784.0, 0.0, 0.09], [988.0, 988.0, 0.06, 0.09], [1175.0, 1175.0, 0.12, 0.09], [1568.0, 1568.0, 0.18, 0.22]], "bell", 0.34],
		"locked": [[[240.0, 220.0, 0.0, 0.07]], "square", 0.22],
		"wrong": [[[200.0, 130.0, 0.0, 0.18]], "square", 0.22],
		"tick": [[[1500.0, 1400.0, 0.0, 0.035]], "sine", 0.35],
		"hint": [[[1200.0, 1800.0, 0.0, 0.12], [1800.0, 2500.0, 0.08, 0.18]], "sine", 0.3],
		"preview": [[[660.0, 990.0, 0.0, 0.14]], "sine", 0.3],
		"pause": [[[740.0, 520.0, 0.0, 0.12]], "triangle", 0.4],
		"shuffle": [[[400.0, 900.0, 0.0, 0.05], [500.0, 1000.0, 0.05, 0.05], [450.0, 950.0, 0.1, 0.05], [600.0, 1100.0, 0.15, 0.05], [520.0, 1050.0, 0.2, 0.05], [700.0, 1300.0, 0.25, 0.08]], "triangle", 0.3],
		"star": [[[1568.0, 1568.0, 0.0, 0.08], [2093.0, 2093.0, 0.05, 0.25]], "bell", 0.33],
		"win": [[[523.3, 523.3, 0.0, 0.16], [659.3, 659.3, 0.12, 0.16], [784.0, 784.0, 0.24, 0.16], [1046.5, 1046.5, 0.36, 0.6], [1318.5, 1318.5, 0.36, 0.6], [1568.0, 1568.0, 0.36, 0.6]], "bell", 0.3],
		"fail": [[[523.3, 523.3, 0.0, 0.22], [440.0, 440.0, 0.2, 0.22], [349.2, 349.2, 0.4, 0.26], [261.6, 220.0, 0.64, 0.6]], "triangle", 0.45],
		"unlock": [[[880.0, 880.0, 0.0, 0.1], [1108.7, 1108.7, 0.08, 0.1], [1318.5, 1318.5, 0.16, 0.35]], "bell", 0.32],
	}
	for key in defs:
		var custom := _find_custom(key)
		if custom != null:
			_streams[key] = custom
			continue
		var d: Array = defs[key]
		_streams[key] = _synth(d[0], str(d[1]), float(d[2]))


func _find_custom(key: String) -> AudioStream:
	for ext in ["wav", "ogg", "mp3"]:
		var path := "res://assets/sounds/%s.%s" % [key, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


## Tiny additive synthesiser: mixes notes with a quick attack and a smooth
## decay, then encodes 16-bit mono PCM.
func _synth(notes: Array, wave: String, volume: float) -> AudioStreamWAV:
	var total := 0.0
	for n in notes:
		total = maxf(total, float(n[2]) + float(n[3]))
	total += 0.02
	var count := int(total * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	buf.fill(0.0)
	var attack := maxi(1, int(0.004 * MIX_RATE))
	for n in notes:
		var f0 := float(n[0])
		var f1 := float(n[1])
		var start := int(float(n[2]) * MIX_RATE)
		var length := maxi(1, int(float(n[3]) * MIX_RATE))
		var phase := 0.0
		for i in length:
			var idx := start + i
			if idx >= count:
				break
			var t := float(i) / float(length)
			phase += TAU * lerpf(f0, f1, t) / MIX_RATE
			var v := 0.0
			match wave:
				"square":
					v = 0.6 if sin(phase) >= 0.0 else -0.6
				"triangle":
					v = (2.0 / PI) * asin(sin(phase))
				"bell":
					v = sin(phase) + 0.35 * sin(phase * 2.0) + 0.12 * sin(phase * 3.01)
				_:
					v = sin(phase) + 0.2 * sin(phase * 2.0)
			var env := minf(1.0, float(i) / attack) * pow(1.0 - t, 1.6)
			buf[idx] += v * env
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var s := clampf(buf[i] * volume, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
