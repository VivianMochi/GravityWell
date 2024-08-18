extends Node2D

var velocity := Vector2(0, 0);
var pull_time: int = 0

func _ready():
	pass

func _process(delta):
	pass

func tick():
	position += velocity;

func velocity_changed():
	# Velocity cap needs to be controlled
	if velocity.length() > 3:
		velocity = velocity.normalized() * 3;
	
	if velocity.length() > 1:
		$Sprite.frame = 1;
	else:
		$Sprite.frame = 0;
