class_name RaidRecapText
extends RefCounted

## Reggie's call about a farm robbed behind Jack's back and the lines of the flashback that replays it.

const ROBBER: String = "Зуб"
const OPERATOR: String = "С телефоном"
const ASK: int = 0
const NOT_NOW: int = 1
const CALL_CHOICES: PackedStringArray = ["Как это было?", "Без подробностей, Реджи."]
const NIGHT_FROM_HOUR: float = 21.0
const NIGHT_UNTIL_HOUR: float = 6.0
## Banter beats in the order the flashback reaches them.
const START: int = 0
const FIRST_CRATE: int = 1
const LOADED: int = 2
const DRIVE_OFF: int = 3
const SKIP_LABEL: String = "Пропустить  [Esc]"
const WALK_HINT: String = "Клик по земле — идти. Клик по контейнеру — выносить ящики."


static func call_lines(robbery: SimEvent) -> Array[DialogueLineDef]:
	var lines: Array[DialogueLineDef] = [
		DialogueLineDef.make("", "Звонит Реджи."),
		DialogueLineDef.make(UiText.REGGIE, "Мистер Кэллоуэй, ферму обнесли…"),
		DialogueLineDef.make(UiText.REGGIE, "«Молочные зубы», около %s. Вынесли %s — всё, что ждало у лифта." % [time_of(robbery), DayText.crates(Raids.crates_taken(robbery))]),
	]
	if String(robbery.data.get("outcome", "")) == "helper_failed":
		lines.append(DialogueLineDef.make(UiText.REGGIE, "Я пробовал их шугануть. Теперь я тоже в клипе."))
	return lines


static func ask_lines() -> Array[DialogueLineDef]:
	return [DialogueLineDef.make(UiText.REGGIE, "Сами сняли, сами выложили. С музыкой. Смотрите.")]


static func closing_lines(robbery: SimEvent, asked: bool) -> Array[DialogueLineDef]:
	if not asked:
		return [DialogueLineDef.make(UiText.REGGIE, "Как скажете. Клип, если что, уже в сети.")]
	return [DialogueLineDef.make(UiText.REGGIE, "Вот так. Уже %d просмотров. Ящики, полагаю, не вернутся." % views(robbery))]


## Display only: grows with the haul, the same every time the story is told.
static func views(robbery: SimEvent) -> int:
	return 1200 + Raids.crates_taken(robbery) * 650 + (robbery.seq % 7) * 90


static func caption(robbery: SimEvent) -> String:
	var hour := hour_of(robbery)
	var when := "Той ночью" if hour >= NIGHT_FROM_HOUR or hour < NIGHT_UNTIL_HOUR else "Тем днём"
	return "%s, %s. «Молочные зубы»." % [when, time_of(robbery)]


static func banter(beat: int) -> DialogueLineDef:
	match beat:
		START:
			return DialogueLineDef.make(OPERATOR, "Пишу. Иди красиво, это для клипа.")
		FIRST_CRATE:
			return DialogueLineDef.make(OPERATOR, "Ящик в кадр. Лицо не надо, у тебя балаклава.")
		LOADED:
			return DialogueLineDef.make(ROBBER, "Лайк, подписка, ящик.")
		_:
			return DialogueLineDef.make(OPERATOR, "Валим. Монтаж к утру.")


static func load_hint(carried: int, total: int) -> String:
	return "Ящики: %d из %d. Ещё заход в контейнер." % [carried, total]


static func car_hint() -> String:
	return "Всё вынесли. Клик по машине — уезжать."


static func hour_of(robbery: SimEvent) -> float:
	return fmod(robbery.game_time, SimClock.GAME_SECONDS_PER_DAY) / SimClock.GAME_SECONDS_PER_HOUR


static func time_of(robbery: SimEvent) -> String:
	var hour := hour_of(robbery)
	var whole := floori(hour)
	return "%02d:%02d" % [whole, floori((hour - float(whole)) * 60.0)]
