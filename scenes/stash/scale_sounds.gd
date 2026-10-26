class_name ScaleSounds
extends RefCounted

## Placeholder sounds for «Весы», synthesised in code: no audio files yet.

const MIX_RATE: int = 22050
const VOLUME: float = 0.25
const POUR_SECONDS: float = 0.5
const POUR_VOLUME: float = 0.08


## A short chime; higher means a better bag.
static func blip(frequency: float, seconds: float = 0.18) -> AudioStreamWAV:
	var count := roundi(seconds * float(MIX_RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	for index: int in count:
		var t := float(index) / float(MIX_RATE)
		var envelope := exp(-t * 14.0) * minf(t / 0.004, 1.0)
		var wave := sin(TAU * frequency * t) + 0.35 * sin(TAU * frequency * 2.0 * t)
		data.encode_s16(index * 2, roundi(clampf(VOLUME * envelope * wave, -1.0, 1.0) * 32767.0))
	return _stream(data, false)


## The stamp coming down on the bag.
static func thud() -> AudioStreamWAV:
	var seconds := 0.16
	var count := roundi(seconds * float(MIX_RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	for index: int in count:
		var t := float(index) / float(MIX_RATE)
		var frequency := lerpf(140.0, 55.0, t / seconds)
		var wave := sin(TAU * frequency * t) * exp(-t * 22.0)
		data.encode_s16(index * 2, roundi(clampf(VOLUME * 1.6 * wave, -1.0, 1.0) * 32767.0))
	return _stream(data, false)


## Dry leaves trickling into the pan, looped while pouring. A fixed hash, not a random source.
static func pour() -> AudioStreamWAV:
	var count := roundi(POUR_SECONDS * float(MIX_RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	var state := 0x2545F491
	var smoothed := 0.0
	for index: int in count:
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var noise := float(state & 0xFFFF) / 32767.5 - 1.0
		smoothed = lerpf(smoothed, noise, 0.35)
		var t := float(index) / float(MIX_RATE)
		var grain := 0.6 + 0.4 * sin(TAU * 23.0 * t)
		data.encode_s16(index * 2, roundi(clampf(POUR_VOLUME * smoothed * grain, -1.0, 1.0) * 32767.0))
	return _stream(data, true)


static func _stream(data: PackedByteArray, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = data.size() / 2
	return stream
