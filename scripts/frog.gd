class_name Frog
extends Figure
## A frog on the boat: a Figure (the boy's rig's body for anyone not the
## player) on the frog model, posed by FrogRig. Give it a look (FrogLook), and
## a part to play or a dance, before it goes in the tree:
##     var frog := Frog.new()
##     frog.look = FrogLook.bandsman(3)
##     frog.part = "tuba"
##     frog.position = Vector3(1, 0, 2)
##     add_child(frog)

const MODEL := preload("res://models/frog.glb")
const MODEL_LOW := preload("res://models/frog_lo.glb")

var look: Dictionary = {}
var part := ""
var dance := "bounce"
var droop := 0.2
## Use the low-poly model (the far crowd).
var low := false
## Where it stands to play or dance, and which way it faces there (it goes back there after a step aside).
var home := Vector3.ZERO
var home_yaw := 0.0


func _init() -> void:
	super._init()
	model = MODEL
	model_low = MODEL_LOW
	walk_speed = 0.9
	run_speed = 2.2
	dusty = false
	radius = 0.22
	height = 1.5


func _ready() -> void:
	if low:
		model = MODEL_LOW
	size = look.get("size", 1.3)
	looseness = 0.75
	super._ready()
	var frog := rig as FrogRig
	frog.look = look
	frog.restyle()
	# (a softer turn from light to shade on the skin than on cloth: a frog is round and wet)
	for mesh: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var made := mesh.mesh.surface_get_material(surface)
			var shaded := mesh.get_surface_override_material(surface) as ShaderMaterial
			if made and shaded and made.resource_name in ["skin", "belly"]:
				shaded.set_shader_parameter(&"wrap", 0.35)
				shaded.set_shader_parameter(&"rim_gain", 0.25)
	var build: float = look.get("build", 1.0)
	rig.scale = Vector3(size * build, size, size * build)
	home = global_position
	home_yaw = facing_yaw


func _new_rig() -> CharacterRig:
	var frog := FrogRig.new()
	frog.part = part
	frog.dance = dance
	frog.droop = droop
	return frog


func frog_rig() -> FrogRig:
	return rig as FrogRig


## Turns to face `yaw` where it stands.
func turn_to(yaw: float) -> void:
	facing_yaw = yaw
	home_yaw = yaw


func _process(delta: float) -> void:
	super._process(delta)
	# Standing still, it keeps to the way it was put facing (Figure turns it only as it moves)
	if not is_going() and Vector2(velocity.x, velocity.z).length() < 0.05:
		facing_yaw = lerp_angle(facing_yaw, home_yaw, 1.0 - exp(-3.0 * delta))
