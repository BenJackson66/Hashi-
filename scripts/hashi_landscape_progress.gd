class_name HashiLandscapeProgress
extends RefCounted
## Presentation is derived from durable Story frontier, never a second currency/save.
const LEVELS := 12
const PARTS := ["El desembarcadero", "El sendero", "La casa del farero", "El faro"]
const ICONS := ["boat", "bridge", "house", "lighthouse"]
const MOMENTS := ["Un lugar donde llegar", "El muelle vuelve a estar firme", "La primera visita", "Un paso hacia el faro", "El camino vuelve a unirnos", "Flores junto al sendero", "Un techo para quedarse", "Las ventanas se iluminan", "Una casa vuelve a ser hogar", "La torre recupera su color", "Todo listo para la noche", "Una luz para volver"]
static func progress(story: Dictionary) -> int:
	return clampi(int(story.get("frontier", 0)), 0, LEVELS)
static func part(done: int) -> int:
	return mini(clampi(done, 0, LEVELS) / 3, 3)
static func title(done: int) -> String:
	return "El faro encendido" if done >= LEVELS else PARTS[part(done)]
static func moment(done: int) -> String:
	return "Un lugar por despertar" if done <= 0 else MOMENTS[clampi(done, 1, LEVELS) - 1]
