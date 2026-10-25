class_name CastDef
extends Resource

## In story order: intros due at the same moment play in this order.
@export var characters: Array[CharacterDef] = []


func find(character_id: String) -> CharacterDef:
	for character: CharacterDef in characters:
		if character.id == character_id:
			return character
	return null
