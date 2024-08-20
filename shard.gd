extends Node2D

var velocity := Vector2(0, 0);
var pull_time: int = 0
var path_save_interval: int = 0;
var path: PackedVector2Array;
var empowered: bool = false;
var empower_level: int = 0;

var CHARGE_DELAY = 35;

func _ready():
	pass

func _process(delta):
	pass

func tick():
	position += velocity;
	
	if pull_time > CHARGE_DELAY:
		path_save_interval += 1;
		if path_save_interval >= 3:
			path_save_interval = 0;
			path.push_back(position);
			if path.size() > 5:
				path.remove_at(0);
		
		queue_redraw()

func velocity_changed():
	# Velocity cap needs to be controllable
	if velocity.length() > 3:
		velocity = velocity.normalized() * 3;
	
	if empowered:
		$Sprite.frame = 3;
	elif pull_time > CHARGE_DELAY:
		$Sprite.frame = 2;
	elif velocity.length() > 1:
		$Sprite.frame = 1;
	else:
		$Sprite.frame = 0;

func _draw():
	# Draw charge pulse
	if not empowered and (pull_time > CHARGE_DELAY and pull_time < CHARGE_DELAY + 10):
		draw_arc(Vector2(), pull_time - CHARGE_DELAY, 0, TAU, 10, Color(1, 0.2, 0.2, lerp(1, 0, (pull_time - CHARGE_DELAY) / 10.0)), 1, false);
	if empowered:
		draw_arc(Vector2(), (pull_time % 30) / 4.0 + 3, 0, TAU, 10, Color(1, 0.5, 0.25, lerp(1, 0, (pull_time % 30) / 30.0)), 1, false);
	
	# Draw trail, have to change the draw transform first as the trail is stored in world coordinates
	draw_set_transform(-position);
	if path.size() > 2:
		draw_polyline(path.slice(0, 3), Color.hex(0xff7b4255) if empowered else Color.hex(0xea1f1f55))
	if path.size() == 5:
		draw_polyline(path.slice(2, 5), Color.hex(0xff7b42aa) if empowered else Color.hex(0xfb1818aa))
