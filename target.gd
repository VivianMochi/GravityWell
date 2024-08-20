extends Node2D

# Signals
signal explode(empower_level);

# Logic stuff
var patrol_points = []
var max_idle_time: int = 0;
var attack_interval: int = -1;

# Active ingredients
var current_point: int = 0;
var idle_time: int = 0;
var animation_time: int = 0;

func generate_move_logic(total_points: int, stationary_time: int):
	total_points = max(total_points, 1)
	for i in range(total_points):
		patrol_points.push_back(generate_point());
	max_idle_time = stationary_time;
	
	# Also move the target off-screen so it can slide in
	position = patrol_points[0] + Vector2(100, 0);

func generate_attack_logic(attack_interval: int, attack_while_moving: bool):
	pass;

func _ready():
	generate_move_logic(1, 1000);

func _process(delta):
	pass

func tick():
	animation_time = wrap(animation_time + 1, 0, 100);
	var move_offset = patrol_points[current_point] + Vector2(0, 3.0 * sin(animation_time / 100.0 * TAU)) - position;
	if move_offset.length() > 1:
		# Move towards point, using similar code from mouse movement
		var direction_atan = atan2(abs(move_offset.y), abs(move_offset.x)) / (PI / 2.0);
		var x_control = direction_atan <= 0.55 or Time.get_ticks_msec() % 2;
		var y_control = direction_atan >= 0.45 or Time.get_ticks_msec() % 2;
		var movement := Vector2(0, 0);
		if move_offset.x > 1 and x_control:
			movement.x += 1;
		if move_offset.x < -1 and x_control:
			movement.x -= 1;
		if move_offset.y > 1 and y_control:
			movement.y += 1;
		if move_offset.y < -1 and y_control:
			movement.y -= 1;
		position += movement;
	else:
		# Stationary for a time
		idle_time += 1;
		if idle_time > max_idle_time:
			idle_time = 0;
			current_point = wrap(current_point + 1, 0, patrol_points.size());
	
	# Sprite frame
	$Sprite.frame = animation_time % 25 / 25.0 * 6;

func generate_point():
	return Vector2(182 + randf() * 40, 40 + randf() * 78);

func _on_area_entered(area):
	# Explode if a charged shard hit
	var shard = area.get_owner() as Shard
	if shard and shard.pull_time > shard.CHARGE_DELAY:
		shard.queue_free();
		explode.emit(shard.empower_level + 1);
