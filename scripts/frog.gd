class_name Frog
extends Node3D
## A frog on the boat: the frog model (one of its bodies, BODIES) posed by FrogRig, standing on
## whatever carries it (the Riverboat, which goes down the river with everyone on it).
##
## It is not a physics body. It moves over the deck by itself (`go_to`, or `drive` from outside),
## in its parent's space, and gives the rig what a body gives it: `velocity` (over the deck),
## `is_on_floor()`, `walk_speed`, `run_speed`, `is_pushing`. So the rig steps and walks as it does
## for the boy, and nothing slides when the boat moves.
## Give it a look (FrogLook), and a part to play or a dance, before it goes in the tree:
##     var frog := Frog.new()
##     frog.look = FrogLook.bandsman(3)
##     frog.part = "tuba"
##     frog.position = Vector3(1, 1.75, -12)
##     boat.add_child(frog)

signal arrived

const BODIES := {
	"round": [preload("res://models/frog_round.glb"), preload("res://models/frog_round_lo.glb")],
	"slim": [preload("res://models/frog_slim.glb"), preload("res://models/frog_slim_lo.glb")],
	"squat": [preload("res://models/frog_squat.glb"), preload("res://models/frog_squat_lo.glb")],
}

var look: Dictionary = {}
var part := ""
var dance := "bounce"
var droop := 0.2
## Use the low-poly model.
var low := false
## Where it stands to play or dance (in its parent's space), and which way it faces there.
var home := Vector3.ZERO
var home_yaw := 0.0
## What the rig reads of its body.
var velocity := Vector3.ZERO
var walk_speed := 0.9
var run_speed := 2.2
var is_pushing := false
var facing_yaw := 0.0
var size := 1.3
var rig: FrogRig

var _goal := Vector3.ZERO
var _going := false
var _driven := false


func _ready() -> void:
	size = look.get("size", 1.3)
	rig = FrogRig.new()
	var models: Array = BODIES.get(look.get("body", "round"), BODIES.round)
	rig.model = models[1 if low else 0]
	rig.part = part
	rig.dance = dance
	rig.droop = droop
	rig.looseness = 0.75
	rig.dusty = false
	# (shaded by FrogToon, below, not by the boy's Toon)
	rig.cel_shaded = false
	rig.head_size = look.get("head", 1.0)
	rig.lag = randf_range(-0.06, 0.06)
	# (each blinks its own way: some quick, some slow, a few with one eye after the other)
	rig.blink_time = look.get("blink_time", randf_range(0.12, 0.24))
	rig.blink_gap = look.get("blink_gap", 0.0 if randf() < 0.7 else randf_range(0.03, 0.12))
	add_child(rig)
	rig.top_level = true
	rig.look = look
	rig.restyle()
	FrogToon.apply(rig._figure, look.get("colours", {}), not low)
	rig.bind_face()
	home = position
	facing_yaw = home_yaw
	_show()


func frog_rig() -> FrogRig:
	return rig


func is_on_floor() -> bool:
	return true


## Sends it to `point` (in its parent's space) at a walk.
func go_to(point: Vector3) -> void:
	_goal = Vector3(point.x, position.y, point.z)
	_going = true
	_driven = false


func stop() -> void:
	_going = false


func is_going() -> bool:
	return _going


## Turns it to face `yaw` where it stands.
func turn_to(yaw: float) -> void:
	home_yaw = yaw


## Moves it from outside (the couples' turns): to `point`, going at `going`, facing `yaw`.
func drive(point: Vector3, going: Vector3, yaw: float) -> void:
	_driven = true
	_going = false
	position = point
	velocity = going
	facing_yaw = yaw
	home_yaw = yaw


func _process(delta: float) -> void:
	if not _driven:
		var wish := Vector3.ZERO
		if _going:
			var to := _goal - position
			to.y = 0.0
			var distance := to.length()
			if distance < 0.06:
				_going = false
				arrived.emit()
			else:
				# (slowing as it comes up to the place, so as to stop on it)
				wish = to / distance * minf(walk_speed, sqrt(2.0 * 4.0 * distance))
		velocity = velocity.move_toward(wish, 4.0 * delta)
		position += velocity * delta
		var heading := Vector2(velocity.x, velocity.z)
		var yaw := atan2(heading.x, heading.y) if heading.length() > 0.15 else home_yaw
		facing_yaw = lerp_angle(facing_yaw, yaw, 1.0 - exp(-5.0 * delta))
	_show()


func _show() -> void:
	if rig == null:
		return
	var build: float = look.get("build", 1.0)
	var carrier := (get_parent() as Node3D).global_basis.orthonormalized() if get_parent() is Node3D else Basis.IDENTITY
	rig.global_transform = Transform3D(carrier * Basis(Vector3.UP, facing_yaw) * Basis.from_scale(Vector3(size * build, size, size * build)), global_position)
