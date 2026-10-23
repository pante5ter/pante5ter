class_name ExactFloat
extends RefCounted

## Godot's JSON parser can land one ulp off when reading 17-digit floats back,
## so saved times travel as the raw 64-bit pattern to keep loads bit-identical.

const ENCODED_LENGTH: int = 16


static func encode(value: float) -> String:
	return PackedFloat64Array([value]).to_byte_array().hex_encode()


static func decode(encoded: Variant) -> float:
	if not encoded is String or (encoded as String).length() != ENCODED_LENGTH:
		return NAN
	return (encoded as String).hex_decode().decode_double(0)
