class_name Vivienne
extends Interactable
## Jack's wife. A short word depending on the hour; her auction-house leads come with the briefing later.


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
