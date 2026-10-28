class_name RaidRecapText
extends RefCounted

## Reggie's call about a farm robbed behind Jack's back, Vivienne's breakfast with the clip, and the
## lines of the clip itself: the gang filming in the bunker.

const ROBBER: String = "Зуб"
const OPERATOR: String = "С телефоном"
const GUARD: String = "Реджи"
const ASK: int = 0
const NOT_NOW: int = 1
const CALL_CHOICES: PackedStringArray = ["Как это было?", "Без подробностей, Реджи."]
const BREAKFAST_CHOICES: PackedStringArray = ["Посмотреть"]
const NIGHT_FROM_HOUR: float = 21.0
const NIGHT_UNTIL_HOUR: float = 6.0
## Banter beats in the order the clip reaches them.
const START: int = 0
const FIRST_CRATE: int = 1
const LOADED: int = 2
const DRIVE_OFF: int = 3
const KNOCKED: int = 4
const GUARD_STEPS_IN: int = 5
const GUARD_DOWN: int = 6
const SKIP_LABEL: String = "Пропустить  [Esc]"
const CLIP_TITLE: String = "«МОЛОЧНЫЕ ЗУБЫ» — ПОДВАЛ (премьера)"
const WALK_HINT: String = "Клик по полу — идти. Клик по ящикам — грузить. Лампы и вёдра можно ронять — для клипа."


static func call_lines(robbery: SimEvent) -> Array[DialogueLineDef]:
	var lines: Array[DialogueLineDef] = [DialogueLineDef.make("", "Звонит Реджи.")]
	lines.append_array(report_lines(robbery))
	return lines


## What Reggie says about the night, whoever showed Jack the clip first.
static func report_lines(robbery: SimEvent) -> Array[DialogueLineDef]:
	var lines: Array[DialogueLineDef] = [
		DialogueLineDef.make(UiText.REGGIE, "Мистер Кэллоуэй, ферму обнесли…"),
		DialogueLineDef.make(UiText.REGGIE, "«Молочные зубы», около %s. Вынесли %s — всё, что ждало у лифта." % [time_of(robbery), DayText.crates(Raids.crates_taken(robbery))]),
	]
	if guard_was_there(robbery):
		lines.append(DialogueLineDef.make(UiText.REGGIE, "Я пробовал их шугануть. Теперь я тоже в клипе."))
	return lines


static func guard_was_there(robbery: SimEvent) -> bool:
	return String(robbery.data.get("outcome", "")) == "helper_failed"


static func ask_lines() -> Array[DialogueLineDef]:
	return [DialogueLineDef.make(UiText.REGGIE, "Сами сняли, сами выложили. С музыкой. Смотрите.")]


static func closing_lines(robbery: SimEvent, asked: bool) -> Array[DialogueLineDef]:
	if not asked:
		return [DialogueLineDef.make(UiText.REGGIE, "Как скажете. Клип, если что, уже в сети.")]
	return [DialogueLineDef.make(UiText.REGGIE, "Вот так. Уже %d просмотров. Ящики, полагаю, не вернутся." % views(robbery))]


static func breakfast_lines(robbery: SimEvent) -> Array[DialogueLineDef]:
	return [
		DialogueLineDef.make("", "Завтрак. Вивьен не здоровается — молча разворачивает к тебе телефон."),
		DialogueLineDef.make(UiText.VIVIENNE, "%d просмотров к завтраку. Мне прислала жена викария — с тремя восклицательными знаками." % views(robbery)),
		DialogueLineDef.make(UiText.VIVIENNE, "И давно вы рекламируете своё секретное место?"),
	]


static func watch_lines() -> Array[DialogueLineDef]:
	return [DialogueLineDef.make(UiText.VIVIENNE, "Сделай погромче. Это у них, видимо, музыка.")]


## Back at the table: Vivienne's verdict, then Reggie's call with the facts.
static func after_breakfast_lines(robbery: SimEvent) -> Array[DialogueLineDef]:
	var lines: Array[DialogueLineDef] = [
		DialogueLineDef.make(UiText.VIVIENNE, "Лампы у тебя красивые, Джек. Жаль, что теперь их видела половина Лондона."),
		DialogueLineDef.make(UiText.JACK, "Доедай без меня."),
		DialogueLineDef.make("", "Звонит Реджи."),
	]
	lines.append_array(report_lines(robbery))
	lines.append(DialogueLineDef.make(UiText.REGGIE, "Клип вы уже видели — по голосу слышу. Буду у вас через полчаса. Привезу кое-что поинтереснее."))
	return lines


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
			return DialogueLineDef.make(OPERATOR, "Пишу. Заходим красиво — это подвал миллионера.")
		FIRST_CRATE:
			return DialogueLineDef.make(OPERATOR, "Ящик в кадр. Лицо не надо, у тебя балаклава.")
		LOADED:
			return DialogueLineDef.make(ROBBER, "Лайк, подписка, ящик.")
		KNOCKED:
			return DialogueLineDef.make(OPERATOR, "Ещё! В кадре смотрится дорого.")
		GUARD_STEPS_IN:
			return DialogueLineDef.make(GUARD, "Молодые люди, вы ошиблись подвалом.")
		GUARD_DOWN:
			return DialogueLineDef.make(ROBBER, "Отдыхай, дед. Ты в кадре — улыбнись.")
		_:
			return DialogueLineDef.make(OPERATOR, "Валим. Монтаж к утру.")


static func load_hint(carried: int, total: int) -> String:
	return "Ящики: %d из %d. Ещё заход к ящикам." % [carried, total]


static func lift_hint() -> String:
	return "Всё взяли. Клик по лифту — наверх."


static func hour_of(robbery: SimEvent) -> float:
	return fmod(robbery.game_time, SimClock.GAME_SECONDS_PER_DAY) / SimClock.GAME_SECONDS_PER_HOUR


static func time_of(robbery: SimEvent) -> String:
	var hour := hour_of(robbery)
	var whole := floori(hour)
	return "%02d:%02d" % [whole, floori((hour - float(whole)) * 60.0)]
