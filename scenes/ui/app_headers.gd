class_name AppHeaders
extends RefCounted

## One line under each app's title: what it is for and what can be done there.


static func phone(app: int) -> String:
	match app:
		Phone.APP_CALLS:
			return "Клиенты звонят сюда. Примите заказ, поторгуйтесь или откажите — пока звонит."
		Phone.APP_MESSAGES:
			return "Реджи пишет, что случилось и что делать дальше."
		Phone.APP_SHOP, Phone.APP_STOCK:
			return "Что есть на складе и что докупить: семена, удобрение, лекарства, грядки. Посылки — к контейнеру."
		Phone.APP_PEOPLE:
			return "Кто на вас работает: бригада, курьеры, фасовщик. Нанять, уволить, отправить Реджи учиться."
		Phone.APP_EMPIRE, Phone.APP_FINANCE:
			return "Деньги, счета, аренда лорду, подозрение и следующий уровень империи."
		Phone.APP_MAP:
			return "Где что на поместье и что требует внимания."
	return ""


static func computer(tab: int) -> String:
	match tab:
		ComputerScreen.TAB_ORDERS:
			return "Принятые заказы. Когда коробки на полке — выберите, кто повезёт, и отправьте."
		ComputerScreen.TAB_FARM:
			return "Подозрение соседей. Едет проверка — затихните: свет и курьеры замирают."
		ComputerScreen.TAB_SHOP:
			return phone(Phone.APP_SHOP)
		ComputerScreen.TAB_PEOPLE, ComputerScreen.TAB_COURIERS:
			return phone(Phone.APP_PEOPLE)
		ComputerScreen.TAB_CLUES:
			return "Улики, которые Реджи приколол к доске: кто под подозрением и почему."
	return ""
