class_name FrogLook
## How a frog (models/frog.glb, tools/build_frogs.py) may be turned out: its
## skin, its hat, coat, neckwear and legs, and the colours of all of them. A
## look is what CharacterRig.look takes: {"parts": slot -> option, "colours":
## material name -> Color}, plus "body" (which model: Frog.BODIES), "head" (how big its head is
## against the model's), "size" and "build" for whoever stands it up, and "droop" (its lids).
##
## Each clothing slot has trimmings that are slots of their own in the model
## (`coattrim`, `necktie`, `hatband`, `hatfeather`); `parts_for` names the same
## option for them as for what they trim.

const HATS := ["top", "bowler", "boater", "bonnet", "helmet", "cap", "fez", "none"]
const COATS := ["tails", "frock", "jacket", "dress", "waistcoat", "none"]
const NECKS := ["bow", "cravat", "scarf", "none"]
const LEGS := ["trousers", "breeches", "none"]
const TRIMS := {"coattrim": "coat", "necktie": "neck", "hatband": "hat", "hatfeather": "hat"}
const BODIES := ["round", "round", "round", "slim", "slim", "squat", "squat"]

## Frog skins: olive, moss, sage, toad brown, bottle green, yellowish; and the pale belly of each.
const SKINS := [Color(0.45, 0.55, 0.27), Color(0.36, 0.48, 0.22), Color(0.52, 0.58, 0.36), Color(0.48, 0.44, 0.26),
		Color(0.30, 0.42, 0.25), Color(0.56, 0.60, 0.26), Color(0.40, 0.50, 0.32)]
const BELLIES := [Color(0.82, 0.80, 0.55), Color(0.76, 0.78, 0.52), Color(0.84, 0.82, 0.64), Color(0.80, 0.72, 0.50)]
## Victorian Sunday best: wine, plum, bottle, navy, brown, slate, mustard, dove grey.
const CLOTHS := [Color(0.42, 0.13, 0.14), Color(0.33, 0.18, 0.30), Color(0.17, 0.27, 0.20), Color(0.16, 0.19, 0.31),
		Color(0.33, 0.22, 0.15), Color(0.28, 0.30, 0.34), Color(0.60, 0.46, 0.20), Color(0.55, 0.53, 0.52),
		Color(0.24, 0.24, 0.42), Color(0.45, 0.30, 0.24)]
const TROUSERS := [Color(0.62, 0.56, 0.46), Color(0.48, 0.44, 0.40), Color(0.22, 0.22, 0.26), Color(0.55, 0.47, 0.38), Color(0.38, 0.36, 0.42)]
const HATS_COLOURS := [Color(0.13, 0.12, 0.13), Color(0.35, 0.25, 0.18), Color(0.55, 0.52, 0.50), Color(0.24, 0.20, 0.30)]
const STRAW := Color(0.86, 0.74, 0.46)
const DRESSES := [Color(0.62, 0.50, 0.70), Color(0.55, 0.66, 0.78), Color(0.78, 0.62, 0.60), Color(0.62, 0.72, 0.58), Color(0.80, 0.74, 0.58)]
const RIBBONS := [Color(0.42, 0.20, 0.30), Color(0.70, 0.30, 0.30), Color(0.25, 0.30, 0.50), Color(0.50, 0.40, 0.20)]
## The band's uniform: scarlet and gold, black caps.
const BAND_RED := Color(0.66, 0.11, 0.10)
const BAND_GOLD := Color(0.88, 0.68, 0.22)


## Shows each slot's option (and its trimmings') and nothing else.
static func parts_for(chosen: Dictionary) -> Dictionary:
	var parts := chosen.duplicate()
	for trim: String in TRIMS:
		parts[trim] = chosen.get(TRIMS[trim], "none")
	for slot: String in ["hat", "coat", "neck", "legs", "warts"]:
		if not parts.has(slot):
			parts[slot] = "none"
	return parts


## Someone in the crowd, from a seed: a gentleman, a lady or a working frog, each dressed to go out.
static func random(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	var pick := func(list: Array) -> Variant: return list[rng.randi() % list.size()]
	var skin: Color = pick.call(SKINS)
	var colours := {"skin": skin.lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.05)}
	# (the throat and belly a shade lighter than the rest, a little more yellow)
	colours["belly"] = (colours.skin as Color).lightened(0.3).lerp(Color(0.86, 0.84, 0.5), 0.15)
	var chosen := {}
	var kind := rng.randf()
	var size := rng.randf_range(1.25, 1.45)
	var build := rng.randf_range(0.94, 1.12)
	var body: String = pick.call(BODIES)
	if kind < 0.3:
		# A lady: a gown and a wide hat with a feather
		chosen = {"coat": "dress", "hat": "bonnet" if rng.randf() < 0.75 else "none", "neck": "none", "legs": "none"}
		colours["dress"] = pick.call(DRESSES)
		colours["hat"] = (pick.call(DRESSES) as Color).lerp(Color.WHITE, 0.3)
		colours["band"] = pick.call(RIBBONS)
		colours["feather"] = Color(0.92, 0.88, 0.95).lerp(pick.call(DRESSES), 0.3)
		colours["collar"] = Color(0.95, 0.93, 0.88)
		size *= 0.95
	elif kind < 0.75:
		# A gentleman: tails or a frock coat, a bow or a cravat, a top hat or a bowler
		chosen = {"coat": pick.call(["tails", "tails", "frock", "frock", "jacket"]), "hat": pick.call(["top", "top", "bowler", "bowler", "boater", "none"]),
				"neck": pick.call(["bow", "bow", "cravat", "scarf"]), "legs": "trousers"}
		colours["coat"] = pick.call(CLOTHS)
		colours["vest"] = (pick.call(CLOTHS) as Color).lerp(Color(0.8, 0.7, 0.4), 0.35)
		colours["trousers"] = pick.call(TROUSERS)
		colours["hat"] = STRAW if chosen.hat == "boater" else pick.call(HATS_COLOURS)
		colours["band"] = pick.call(RIBBONS)
		colours["tie"] = pick.call([Color(0.75, 0.62, 0.20), Color(0.85, 0.82, 0.72), Color(0.45, 0.15, 0.20), Color(0.2, 0.2, 0.3)])
		colours["trim"] = Color(0.80, 0.66, 0.30)
	else:
		# A working frog in his best: waistcoat or jacket, a cap, breeches perhaps
		chosen = {"coat": pick.call(["waistcoat", "jacket", "waistcoat", "none"]), "hat": pick.call(["cap", "boater", "fez", "helmet", "none"]),
				"neck": pick.call(["scarf", "none", "bow"]), "legs": pick.call(["trousers", "breeches"])}
		colours["coat"] = pick.call(CLOTHS)
		colours["vest"] = pick.call(CLOTHS)
		colours["trousers"] = pick.call(TROUSERS)
		colours["hat"] = STRAW if chosen.hat == "boater" else (Color(0.16, 0.18, 0.30) if chosen.hat == "helmet" else pick.call(HATS_COLOURS))
		colours["band"] = pick.call(RIBBONS) if chosen.hat != "helmet" else Color(0.85, 0.75, 0.40)
		colours["tie"] = pick.call([Color(0.70, 0.25, 0.20), Color(0.30, 0.40, 0.55), Color(0.60, 0.55, 0.35)])
		colours["trim"] = Color(0.75, 0.62, 0.32)
		if chosen.hat == "helmet":
			colours["coat"] = Color(0.16, 0.18, 0.30)
			chosen.coat = "jacket"
	# (a few are warty: most of the toads, now and then a frog)
	if rng.randf() < (0.6 if body == "squat" else 0.1):
		chosen["warts"] = "on"
		colours["skin"] = (colours["skin"] as Color).lerp(Color(0.45, 0.40, 0.24), 0.4)
	return {"parts": parts_for(chosen), "colours": colours, "size": size, "build": build, "body": body,
			"head": rng.randf_range(0.92, 1.1), "droop": rng.randf_range(0.1, 0.5)}


## The singer at the front of the bandstand: tails and a bow tie in the band's scarlet, no hat.
static func singer(seed: int) -> Dictionary:
	var made := bandsman(seed)
	made["parts"] = parts_for({"coat": "tails", "neck": "bow", "legs": "trousers", "hat": "none"})
	made["colours"]["vest"] = BAND_GOLD
	made["colours"]["tie"] = Color(0.10, 0.09, 0.10)
	made["body"] = "slim"
	made["size"] = 1.4
	made["head"] = 1.05
	return made


## A bandsman: scarlet coat with gold, a black shako with a gold band. The
## conductor wears tails and a top hat in the same scarlet.
static func bandsman(seed: int, conductor := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 104729 + 7
	var colours := {
		"skin": SKINS[rng.randi() % SKINS.size()], "belly": Color.WHITE,
		"coat": BAND_RED, "trim": BAND_GOLD, "trousers": Color(0.14, 0.14, 0.18), "hat": Color(0.10, 0.09, 0.10),
		"band": BAND_GOLD, "vest": Color(0.92, 0.88, 0.80), "collar": Color(0.95, 0.93, 0.88), "tie": Color(0.10, 0.09, 0.10),
	}
	colours["belly"] = (colours.skin as Color).lightened(0.3).lerp(Color(0.86, 0.84, 0.5), 0.15)
	var chosen := {"coat": "band", "hat": "shako", "neck": "none", "legs": "trousers"}
	if conductor:
		chosen = {"coat": "tails", "hat": "top", "neck": "bow", "legs": "trousers"}
		colours["hat"] = BAND_RED.darkened(0.15)
		colours["band"] = BAND_GOLD
	return {"parts": parts_for(chosen), "colours": colours, "size": rng.randf_range(1.28, 1.42) if not conductor else 1.45,
			"build": rng.randf_range(0.96, 1.1), "body": "round" if conductor else ["round", "squat", "slim"][rng.randi() % 3],
			"head": rng.randf_range(0.95, 1.08), "droop": rng.randf_range(0.15, 0.35)}
