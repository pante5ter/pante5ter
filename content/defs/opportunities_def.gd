class_name OpportunitiesDef
extends Resource

## Vivienne's morning gossip turned into business. Her first line of day d is
## GOSSIP[(d * gossip_stride) % size]; the lists below are indexed the same way.

@export var gossip_stride: int = 5
## Per gossip line: Opportunities.SALE, LEAD, PARTY or empty for idle talk.
@export var gossip_kinds: Array[String] = []
## Per gossip line: what it means for business, for the news.
@export var gossip_notes: Array[String] = []
@export var start_day: int = 2
## Game hour the day's opportunity opens.
@export var open_hour: float = 7.0

@export_group("Sale")
@export_range(0.0, 1.0) var sale_discount: float = 0.4
@export var sale_hours: float = 15.0

@export_group("Lead")
@export var lead_days: float = 5.0

@export_group("Party")
@export var party_quantity_min: int = 8
@export var party_quantity_max: int = 14
@export var party_min_quality: int = 55
## Over the plain price of the boxes.
@export var party_price_multiplier: float = 2.0
@export var party_answer_hours: float = 6.0
@export var party_deadline_hours: float = 30.0


func kind_for(gossip_index: int) -> String:
	return gossip_kinds[gossip_index] if gossip_index >= 0 and gossip_index < gossip_kinds.size() else ""


func note_for(gossip_index: int) -> String:
	return gossip_notes[gossip_index] if gossip_index >= 0 and gossip_index < gossip_notes.size() else ""
