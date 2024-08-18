extends Node2D

var velocity := Vector2(0, 0);

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
	
	if velocity.length() > 3:
		$Sprite.frame = 2;
	elif velocity.length() > 1.5:
		$Sprite.frame = 1;
	else:
		$Sprite.frame = 0;
