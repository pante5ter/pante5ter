class_name Vivienne
extends Interactable
## Jack's wife. A short word depending on the hour; her auction-house leads come with the briefing later.

## Village news over breakfast after a night at home, one per morning in turn.
const GOSSIP: PackedStringArray = [
	"Леди Фэрфакс снова «отдала фамильное серебро в чистку». Третий раз за год. Чистка, судя по всему, называется «Сотбис».",
	"Полковник Добсон продаёт «Констебла» из столовой. Говорит, надоел. Банку, говорят, надоел сам полковник.",
	"Викарий опять собирает на крышу. По моим подсчётам, крыша церкви уже золотая.",
	"Миссис Пембертон уверяет, что ночью по дороге ездят машины с погашенными фарами. Я сказала — лисы. Лисы, Джек, — это теперь твоя репутация.",
	"У Харкортов распродажа: фарфор, два спаниеля и, кажется, младший сын. Спаниелей жалко.",
	"В клубе спрашивали, чем ты занимаешься. Я сказала — сельским хозяйством. Почти не соврала.",
	"Леди Эшкомб надевала жемчуг на благотворительный вечер. Говорит, в последний раз. Жемчуг, по-моему, уже в ломбарде, а это копия.",
]


func hover_text() -> String:
	return "%s — поговорить" % UiText.VIVIENNE


func interact(level: Level) -> void:
	level.hud.play_dialogue(lines(Game.sim))


static func lines(sim: SimState) -> Array[DialogueLineDef]:
	var hour := sim.clock.hour_of_day()
	var said: Array[DialogueLineDef] = []
	if hour < 11.0 and hour >= 5.0:
		said.append(DialogueLineDef.make(UiText.VIVIENNE, "Кофе на столе. Реджи уже ждёт у машины — постарайся вернуться к ужину."))
	elif sim.day.enabled() and hour >= sim.config.day.evening_hour:
		said.append(DialogueLineDef.make(UiText.VIVIENNE, "Ты дома. Значит, на сегодня всё. Иди спать, Джек, утро у тебя наверняка снова «срочное»."))
	elif hour < 5.0:
		said.append(DialogueLineDef.make(UiText.VIVIENNE, "Три часа ночи, Джек. Я не спрашиваю, где ты был. Я спрашиваю, когда ты ляжешь."))
	else:
		said.append(DialogueLineDef.make(UiText.VIVIENNE, "Обед дома — это мило. Но твои грядки, полагаю, сами себя не польют."))
	return said


## Breakfast after a night at home: the village news, and what the evening at the bridge table brought.
static func morning_lines(home_night: SimEvent) -> Array[DialogueLineDef]:
	var morning := floori(home_night.game_time / SimClock.GAME_SECONDS_PER_DAY)
	var said: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.VIVIENNE, GOSSIP[morning % GOSSIP.size()])]
	var bonus := int(home_night.data.get("bonus", 0))
	if bonus > 0:
		said.append(DialogueLineDef.make(UiText.VIVIENNE, "И да: вчера в бридж я обыграла жену викария на %s. Положила в кассу. Она играет, как молится, — с надеждой." % UiText.money(bonus)))
	return said
