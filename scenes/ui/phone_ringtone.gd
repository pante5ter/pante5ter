class_name PhoneRingtone
extends RefCounted

## A British double ring (400 + 450 Hz, two 0.4 s bursts) synthesised in code: no audio files.

const MIX_RATE: int = 22050
const TONES: PackedFloat32Array = [400.0, 450.0]
const BURSTS: PackedFloat32Array = [0.0, 0.6]
const BURST_SECONDS: float = 0.4
const LENGTH_SECONDS: float = 1.0
const VOLUME: float = 0.22
const EDGE_SECONDS: float = 0.01


static func make() -> AudioStreamWAV:
	var count := roundi(LENGTH_SECONDS * float(MIX_RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	for index: int in count:
		var t := float(index) / float(MIX_RATE)
		data.encode_s16(index * 2, roundi(_sample(t) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _sample(t: float) -> float:
	for start: float in BURSTS:
		var local := t - start
		if local < 0.0 or local > BURST_SECONDS:
			continue
		var envelope := minf(minf(local, BURST_SECONDS - local) / EDGE_SECONDS, 1.0)
		var wave := 0.0
		for tone: float in TONES:
			wave += sin(TAU * tone * t)
		return VOLUME * envelope * wave / float(TONES.size())
	return 0.0
