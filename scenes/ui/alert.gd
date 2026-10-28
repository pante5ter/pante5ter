class_name Alert
extends RefCounted

## An urgent piece of news for the top banner. Dangerous ones stay until the player says «Понял»
## or the situation is over; the rest fade on their own.

enum Severity { INFO, GOOD, WARNING, DANGER }

const RAID: String = "raid"
const INSPECTION: String = "inspection"
const PARCEL: String = "parcel"
const CALL: String = "call"
const COURIER: String = "courier"
const PAID: String = "paid"
const HOME: String = "home"
const HAUL: String = "haul"
const WORKER: String = "worker"
const SUMMONS: String = "summons"
const RENT_CALL: String = "rent_call"
const STORY_CALL: String = "story_call"

const SHOW: String = "Показать"
const ANSWER: String = "Ответить"
const GO_HOME: String = "Домой"
const LOOK_AT_FARM: String = "На ферму"
const PREPARE: String = "Подготовиться"

var severity: Severity = Severity.INFO
var topic: String = ""
var glyph: String = ""
var title: String = ""
var body: String = ""
var sticky: bool = false
var action: String = ""
var seconds: float = 8.0


static func make(alert_severity: Severity, alert_topic: String, alert_glyph: String, alert_title: String, alert_body: String) -> Alert:
	var alert := Alert.new()
	alert.severity = alert_severity
	alert.topic = alert_topic
	alert.glyph = alert_glyph
	alert.title = alert_title
	alert.body = alert_body
	alert.sticky = alert_severity == Severity.DANGER or alert_severity == Severity.WARNING
	return alert


## Null when the event is ordinary news for the bottom line.
static func from_event(event: SimEvent, sim: SimState) -> Alert:
	var news := UiText.announcement(event, sim)
	match event.type:
		EventLog.RAID_STARTED:
			var raid := make(Severity.DANGER, RAID, PhoneGlyphs.DANGER, "Налёт у контейнера", news)
			raid.action = SHOW
			return raid
		EventLog.INSPECTION_WARNED:
			var inspect := make(Severity.WARNING, INSPECTION, PhoneGlyphs.INSPECTION, "Скоро проверка", news)
			inspect.action = PREPARE
			return inspect
		EventLog.RENT_CALLED:
			var rent := make(Severity.WARNING, RENT_CALL, PhoneGlyphs.CALLS, "Звонит лорд Эшкомб", news)
			rent.action = ANSWER
			rent.sticky = true
			return rent
		EventLog.STORY_STARTED:
			var started := sim.stories.find(String(event.data.get("story_id", "")))
			if started != null and started.place == StoryDef.MANOR:
				var butler := make(Severity.WARNING, SUMMONS, PhoneGlyphs.CALLS, "Звонит дворецкий", news)
				butler.action = ANSWER
				butler.sticky = true
				return butler
			if started != null and started.place == StoryDef.CALL:
				var who := started.lines[0].speaker if not started.lines.is_empty() and not started.lines[0].speaker.is_empty() else "Неизвестный"
				var ring := make(Severity.INFO, STORY_CALL, PhoneGlyphs.CALLS, "Звонит %s" % who, "Возьмите трубку — Tab или «Ответить».")
				ring.action = ANSWER
				ring.sticky = true
				ring.seconds = 12.0
				return ring
		EventLog.SUPPLY_DELIVERED:
			var where := "Ящик у двери контейнера, на краю пшеничного поля: %s × %d. Подойдите и кликните по нему." % [UiText.item_name(String(event.data["item"]), sim), int(event.data["quantity"])]
			var parcel := make(Severity.INFO, PARCEL, PhoneGlyphs.STOCK, "Посылка приехала", where)
			parcel.action = SHOW
			parcel.seconds = 10.0
			return parcel
		EventLog.ORDER_RECEIVED:
			var offer := "%d шт.%s, качество от %d, платит %s. Ответьте по телефону." % [int(event.data["quantity"]), UiText.order_strain(String(event.data.get("strain_id", "")), sim), int(event.data["min_quality"]), UiText.money(int(event.data["reward"]))]
			var urgent: bool = event.data.get("urgent", false) == true
			var call := make(Severity.INFO, CALL, PhoneGlyphs.CALLS, "Срочный звонок" if urgent else "Звонит клиент" + UiText.order_kind(String(event.data.get("kind", ""))), news if urgent else offer)
			call.action = ANSWER
			call.seconds = 10.0
			return call
		EventLog.ORDER_PAID:
			return make(Severity.GOOD, PAID, PhoneGlyphs.MONEY, "Заказ оплачен", news)
		EventLog.COURIER_HIRED:
			var hired := make(Severity.INFO, COURIER, PhoneGlyphs.PEOPLE, "%s на месте" % UiText.courier_name(String(event.data["courier_id"]), sim), "%s ждёт у дороги у поля — видно с пшеницы, к контейнеру не подпускаем. Подойдите и поговорите." % UiText.courier_name(String(event.data["courier_id"]), sim))
			hired.action = SHOW
			hired.seconds = 12.0
			return hired
		EventLog.COURIER_STOLE:
			return make(Severity.DANGER, COURIER, PhoneGlyphs.DANGER, "Курьер сбежал с товаром", news)
		EventLog.DELIVERY_STOPPED:
			return make(Severity.DANGER, COURIER, PhoneGlyphs.DANGER, "Заказ перехватили", news)
		EventLog.HAUL_STOPPED:
			return make(Severity.DANGER, HAUL, PhoneGlyphs.DANGER, "Ящики перехватили", news)
		EventLog.WORKER_UNPAID:
			return make(Severity.WARNING, WORKER, PhoneGlyphs.MONEY, "%s без зарплаты" % UiText.person(event, sim).display_name, news)
		EventLog.WORKER_QUIT:
			var person := UiText.person(event, sim)
			return make(Severity.DANGER, WORKER, PhoneGlyphs.DANGER, "%s %s с фермы" % [person.display_name, PeopleText.left_word(person)], news)
		EventLog.EVENING_CALL:
			var call_home := make(Severity.INFO, HOME, PhoneGlyphs.CALLS, "Реджи: пора домой", news)
			call_home.action = GO_HOME
			call_home.sticky = true
			return call_home
	return null


## False once the thing the alert is about has gone away: the gang left, the parcel was taken.
static func is_live(alert_topic: String, sim: SimState) -> bool:
	match alert_topic:
		RAID:
			return sim.raids.pending
		INSPECTION:
			return sim.suspicion.inspection_pending()
		PARCEL:
			return not sim.supplies.parcel().is_empty()
		CALL:
			return not sim.orders.with_status(Order.Status.OFFERED).is_empty()
		RENT_CALL:
			return sim.rent.call_pending()
		SUMMONS:
			var manor := sim.stories.pending()
			return manor != null and manor.place == StoryDef.MANOR
		STORY_CALL:
			var call := sim.stories.pending()
			return call != null and call.place == StoryDef.CALL
		HOME:
			return not sim.day.is_home() and not sim.day.travelling()
		COURIER:
			return not sim.couriers.hired.is_empty()
	return true


## Trouble that happens at the container, wherever Jack is.
static func is_farm_trouble(alert_topic: String) -> bool:
	return alert_topic == RAID or alert_topic == INSPECTION


static func topic_title(alert_topic: String) -> String:
	match alert_topic:
		RAID:
			return "Гопники"
		INSPECTION:
			return "Проверка"
		PARCEL:
			return "Посылка"
		COURIER:
			return "Курьер"
	return ""


static func topic_severity(alert_topic: String) -> Severity:
	match alert_topic:
		RAID:
			return Severity.DANGER
		INSPECTION:
			return Severity.WARNING
	return Severity.INFO


static func fill_color(alert_severity: Severity) -> Color:
	match alert_severity:
		Severity.DANGER:
			return PhoneKit.DANGER
		Severity.WARNING:
			return PhoneKit.WARNING
		Severity.GOOD:
			return PhoneKit.GOOD
	return PhoneKit.INFO


static func ink_color(alert_severity: Severity) -> Color:
	return PhoneKit.INK if alert_severity == Severity.WARNING else PhoneKit.TEXT
