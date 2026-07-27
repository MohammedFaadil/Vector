extends Node
## SfxFactory (autoload) — synthesizes every sound in the game at startup so the
## project ships with ZERO audio assets and still sounds produced.
## All sounds are 16-bit 44.1kHz AudioStreamWAV built from raw samples.
## Total memory cost: ~a few MB of RAM, zero VRAM. Replace any entry with a real
## .ogg later by assigning AudioManager.sfx["name"] = preload("res://audio/x.ogg").

const RATE := 44100

var sounds: Dictionary = {}   # name -> AudioStreamWAV
var music: Dictionary = {}    # theme name -> looping AudioStreamWAV pad

func _ready() -> void:
	# Short one-shots.
	sounds["jump"] = _sweep(320.0, 620.0, 0.16, 0.5, 0.002)
	sounds["double_jump"] = _sweep(420.0, 880.0, 0.14, 0.45, 0.002)
	sounds["land_soft"] = _thud(110.0, 0.12, 0.5)
	sounds["land_hard"] = _thud(70.0, 0.22, 0.9)
	sounds["roll"] = _noise_burst(0.16, 0.25, 900.0)
	sounds["slide"] = _noise_burst(0.5, 0.18, 1400.0)
	sounds["vault"] = _sweep(500.0, 300.0, 0.12, 0.35, 0.002)
	sounds["wall_run"] = _noise_burst(0.3, 0.2, 2000.0)
	sounds["ledge_grab"] = _thud(180.0, 0.1, 0.45)
	sounds["footstep"] = _thud(140.0, 0.05, 0.16)
	sounds["coin"] = _arpeggio([880.0, 1108.7, 1318.5], 0.055, 0.4)
	sounds["combo"] = _arpeggio([659.3, 830.6, 987.8, 1318.5], 0.05, 0.42)
	sounds["death"] = _death_sound()
	sounds["ui_click"] = _sweep(700.0, 500.0, 0.05, 0.3, 0.001)
	sounds["ui_hover"] = _sweep(500.0, 560.0, 0.04, 0.15, 0.001)
	sounds["whoosh"] = _noise_burst(0.22, 0.3, 600.0)
	sounds["heartbeat"] = _thud(55.0, 0.3, 0.7)
	# Looping ambient music pads, one per level theme (seamless loops).
	# Rendered at half rate (22.05 kHz) — inaudible for soft pads, and it
	# keeps total synthesis under ~1s of startup time.
	music["dusk"] = _pad([110.0, 164.8, 220.0, 277.2], 5.0, 0.16)
	music["storm"] = _pad([98.0, 146.8, 185.0, 246.9], 5.0, 0.18)
	music["neon"] = _pad([130.8, 196.0, 261.6, 329.6], 5.0, 0.17)
	music["menu"] = _pad([87.3, 130.8, 174.6, 220.0], 5.0, 0.14)

func _make_wav(samples: PackedFloat32Array, loop: bool = false, rate: int = RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

## Pitch sweep with exponential decay — jumps, UI, vaults.
func _sweep(f0: float, f1: float, dur: float, amp: float, attack: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += TAU * f / RATE
		var env := minf(float(i) / (attack * RATE + 1.0), 1.0) * pow(1.0 - t, 2.2)
		s[i] = sin(phase) * env * amp + sin(phase * 2.0) * env * amp * 0.25
	return _make_wav(s)

## Low sine knock with fast decay — landings, grabs, footsteps.
func _thud(freq: float, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / n
		phase += TAU * freq * (1.0 - t * 0.4) / RATE
		var env := pow(1.0 - t, 3.0)
		s[i] = (sin(phase) * 0.85 + rng.randf_range(-1, 1) * 0.15) * env * amp
	return _make_wav(s)

## Filtered noise — slides, wall-runs, whooshes. cutoff shapes the hiss.
func _noise_burst(dur: float, amp: float, cutoff: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var lp := 0.0
	var k := clampf(cutoff / RATE * TAU, 0.0, 1.0)
	for i in n:
		var t := float(i) / n
		lp += (rng.randf_range(-1, 1) - lp) * k
		var env := sin(t * PI)  # fade in and out
		s[i] = lp * env * amp
	return _make_wav(s)

## Quick ascending notes — coins and combos.
func _arpeggio(freqs: Array, note_dur: float, amp: float) -> AudioStreamWAV:
	var per := int(note_dur * RATE)
	var s := PackedFloat32Array()
	s.resize(per * freqs.size())
	for j in freqs.size():
		var phase := 0.0
		for i in per:
			var t := float(i) / per
			phase += TAU * freqs[j] / RATE
			var env := pow(1.0 - t, 1.5)
			s[j * per + i] = (sin(phase) + 0.3 * sin(phase * 2.0)) * env * amp
	return _make_wav(s)

## Descending detuned drone — the dissolve/death sting.
func _death_sound() -> AudioStreamWAV:
	var dur := 0.9
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var p1 := 0.0
	var p2 := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(300.0, 60.0, pow(t, 0.6))
		p1 += TAU * f / RATE
		p2 += TAU * f * 1.02 / RATE
		var env := pow(1.0 - t, 1.4)
		s[i] = (sin(p1) * 0.5 + sin(p2) * 0.4) * env * 0.6
	return _make_wav(s)

## Seamless looping chord pad with slow LFO shimmer — the music beds.
func _pad(freqs: Array, dur: float, amp: float) -> AudioStreamWAV:
	var pad_rate := RATE / 2   # 22.05 kHz is plenty for a mellow pad
	var n := int(dur * pad_rate)
	var s := PackedFloat32Array()
	s.resize(n)
	for j in freqs.size():
		var f: float = freqs[j]
		# Snap each partial to a whole number of cycles so the loop is seamless.
		var cycles := roundf(f * dur)
		var fs := cycles / dur
		for i in n:
			var t := float(i) / pad_rate
			var lfo := 0.7 + 0.3 * sin(TAU * (j + 1) * t / dur)
			s[i] += sin(TAU * fs * t) * lfo * amp / freqs.size()
			s[i] += sin(TAU * fs * 2.0 * t) * lfo * amp * 0.2 / freqs.size()
	return _make_wav(s, true, pad_rate)
