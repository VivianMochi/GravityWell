extends Node2D

var velocity := Vector2(0, 0);
var homing: bool = false;

func _ready():
	pass

func _process(delta):
	pass

func tick():
	position += velocity;

func velocity_changed():
	# Velocity cap of 4 feels okay
	if velocity.length() > 4:
		velocity = velocity.normalized() * 4;
	
	$Sprite.frame_coords.y = 1 if homing else 0;
	if velocity.length() > 3:
		$Sprite.frame_coords.x = 2;
	elif velocity.length() > 1.5:
		$Sprite.frame_coords.x = 1;
	else:
		$Sprite.frame_coords.x = 0;
