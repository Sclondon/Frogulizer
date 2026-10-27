class_name KeyPoses
## Key poses for the boy's moves, set by hand in Character Studio (Animate, Keys)
## and blended in by CharacterRig over what it works out for itself. Written by
## the studio: change them there, not here.
##
## move -> its keys, in order of `at`. Each key is where in the move it falls
## (see CharacterRig.CLIPS: through a stride 0..1, or seconds or a share of the
## way through a move that starts and ends) and, for each bone it changes, a
## turn in that bone's own axes, applied after the rig has posed it.

const KEYS := {}
