class_name IntrigueClue
extends RefCounted

## One clue pinned to the cork board: what it says, where Reggie dug it up and when.
var key: String = ""
## Whose card it hangs under; empty for facts about the raid that name nobody.
var suspect_id: String = ""
var text: String = ""
var place: String = ""
var found_at: float = 0.0
var number: int = 0
