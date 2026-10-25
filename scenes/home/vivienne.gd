class_name Vivienne
extends Interactable
## Jack's wife. A word for the hour, and the village news over breakfast after a night at home.
## She never says the same line twice in one day or twice running.

## Village news: in the morning, over breakfast or when Jack asks.
const GOSSIP: PackedStringArray = [
	"Леди Фэрфакс третий раз за год отдала фамильное серебро «в чистку». Чистка, судя по каталогу, называется «Сотбис».",
	"Полковник Добсон продаёт с аукциона пейзаж Констебла из своей столовой: банк требует долг. Полковник уверяет, что просто устал от коров на стене.",
	"Викарий снова собирает деньги на крышу церкви. Приход платит за неё четвёртый год — крыша, видимо, будет золотая.",
	"Миссис Пембертон говорит, что по ночам с поля выезжает машина и едет через деревню. Я сказала — фермеры встают рано. Она ответила, что фермеры рано встают, а не поздно ложатся.",
	"Харкорты распродают имущество: фарфор, ружья и двух спаниелей. Спаниелей разберут первыми — единственный лот без трещин.",
	"В гольф-клубе спрашивали, чем ты занимаешься. Я сказала — сельским хозяйством. Почти не соврала.",
	"Леди Эшкомб пришла на благотворительный вечер в жемчуге, который все считали заложенным. Либо дела у Эшкомбов наладились, либо ломбард даёт напрокат.",
	"Мистер Тиббет третий год подряд берёт приз за самую большую тыкву, и соседи требуют проверить его удобрения. Зависть в деревне растёт быстрее тыкв.",
	"Сын викария вернулся из Лондона с серьгой в ухе. Викарий теперь молится за него громче, чем за крышу.",
]
## When Jack gets home in the evening.
const EVENING: PackedStringArray = [
	"Ты дома, и даже до полуночи. Запишу в дневник рядом с солнечным затмением.",
	"Ужин остыл час назад. Разогревать не стала: ты всё равно ешь, глядя в телефон.",
	"От тебя пахнет землёй, Джек. Соседи решат, что ты наконец занялся садом. Не разубеждай их.",
	"Реджи опять поставил машину на мои розы. Передай ему: розы старше его машины и злопамятнее.",
	"Звонила твоя мать. Я сказала, что ты работаешь допоздна. Она спросила кем. Я сменила тему.",
	"Иди спать, Джек. Утро у тебя снова будет «срочное» — других у тебя не бывает.",
	"Как прошёл день, не спрашиваю. Если бы хорошо, ты бы рассказал ещё в дверях.",
]
const AFTERNOON: PackedStringArray = [
	"Обед дома — это мило. Но грядки, полагаю, сами себя не польют.",
	"Ты днём дома? Соседи решат, что мы разорились. Езжай, Джек, спасай репутацию.",
	"Я в саду до четырёх. Если что-то срочное — оно подождёт до четырёх.",
]
const NIGHT: PackedStringArray = [
	"Ночь на дворе, Джек. Я не спрашиваю, где ты был. Я спрашиваю, когда ты ляжешь.",
	"Если ищешь ужин — его доел Реджи. Если ищешь меня — я сплю. Ложись.",
]
## When she has said everything a pool holds for the day.
const SAID_ALL: PackedStringArray = [
	"Новости на сегодня кончились, Джек. Деревня столько за день не успевает.",
	"Я всё рассказала. Повторять не буду — ты и в первый раз слушал вполуха.",
]
## Each day the pools start from a different line; coprime with every pool size.
const DAY_STRIDE: int = 5
const MORNING_FROM_HOUR: float = 5.0
const MORNING_TO_HOUR: float = 11.0

## What she said today and her last line. The view's memory, not the sim's: after a load she may
## open the day with a line heard before, never with the same one twice running.
static var _said_day: int = -1
static var _said_today: PackedStringArray = PackedStringArray()
static var _last_said: String = ""


func hover_text() -> String:
	return "%s — поговорить" % UiText.VIVIENNE


func interact(level: Level) -> void:
	level.hud.play_dialogue(lines(Game.sim))


static func lines(sim: SimState) -> Array[DialogueLineDef]:
	return [DialogueLineDef.make(UiText.VIVIENNE, say(pool_for(sim), sim.clock.day()))]


static func pool_for(sim: SimState) -> PackedStringArray:
	var hour := sim.clock.hour_of_day()
	if hour >= MORNING_FROM_HOUR and hour < MORNING_TO_HOUR:
		return GOSSIP
	if hour < MORNING_FROM_HOUR:
		return NIGHT
	if sim.day.enabled() and hour >= sim.config.day.evening_hour:
		return EVENING
	return AFTERNOON


## Breakfast after a night at home: the village news, and what the evening at the bridge table brought.
static func morning_lines(home_night: SimEvent) -> Array[DialogueLineDef]:
	var morning := floori(home_night.game_time / SimClock.GAME_SECONDS_PER_DAY)
	var said: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.VIVIENNE, say(GOSSIP, morning))]
	var bonus := int(home_night.data.get("bonus", 0))
	if bonus > 0:
		said.append(DialogueLineDef.make(UiText.VIVIENNE, "И да: вчера в бридж я обыграла жену викария на %s. Положила в кассу. Она играет, как молится, — с надеждой." % UiText.money(bonus)))
	return said


## The next line of the pool she has not said today and did not say last.
static func say(pool: PackedStringArray, day: int) -> String:
	if day != _said_day:
		_said_day = day
		_said_today.clear()
	var start := posmod(day * DAY_STRIDE, pool.size())
	for step: int in pool.size():
		var line := pool[(start + step) % pool.size()]
		if not _said_today.has(line) and line != _last_said:
			return _remember(line)
	return _remember(SAID_ALL[1] if _last_said == SAID_ALL[0] else SAID_ALL[0])


static func _remember(line: String) -> String:
	_said_today.append(line)
	_last_said = line
	return line


## Tests start her memory clean.
static func forget() -> void:
	_said_day = -1
	_said_today.clear()
	_last_said = ""
