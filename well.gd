extends Node2D

# Signals
signal absorbed(dust);
signal transmit_mass;
signal fractured(shard);

# Stat control
var aura_min = 10;
var aura_max = 50;
var base_move_speed = 1;

# Bounds of movement
var left_barrier = 4;
var right_barrier = 100;
var top_barrier = 27;
var bottom_barrier = 131;

# Active ingredients
var controlled := false;
var dead := false;
var aura_radius: float = 2;
var aura_radius_desired: float = 2;
var aura_center := Vector2(0, 0);
var anti_mode := false;
var orbiting: int = 0;

# For visuals
var aura_pulse_factor = 0;

# Mouse control
var mouse_enabled: bool = false;

func _ready():
	pass;

func _process(delta):
	# Update visuals
	aura_pulse_factor = wrap(aura_pulse_factor + delta * 0.5, 0, 1.0);
	
func tick():
	# All input stuff is locked behind controlled
	if controlled:
		# Transition in and out of anti-mode
		var input_anti = Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT);
		if not anti_mode and input_anti:
			anti_mode = true
			transmit_mass.emit();
			aura_radius = 2;
			aura_radius_desired = 2;
		elif anti_mode and not input_anti:
			anti_mode = false;
			aura_radius_desired = aura_min;
		
		# Boil down inputs
		var input_right = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
		var input_left = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
		var input_up = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
		var input_down = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
		
		# Determine mouse input
		if input_right or input_left or input_down or input_up:
			mouse_enabled = false;
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			mouse_enabled = true;
		if mouse_enabled:
			# Code for smooth-ish diagonal movement, it's not that great but it works well enough
			# Figure out if angle of movement is mainly x or y direction, the majority axis gets full movement
			# Throttle the other axis's movement by 50%
			var mouse_offset = get_viewport().get_mouse_position() - position;
			var mouse_atan = atan2(abs(mouse_offset.y), abs(mouse_offset.x)) / (PI / 2.0);
			var x_control = mouse_atan <= 0.55 or Time.get_ticks_msec() % 2;
			var y_control = mouse_atan >= 0.45 or Time.get_ticks_msec() % 2;
			if mouse_offset.x > 1 and x_control:
				input_right = true;
			if mouse_offset.x < -1 and x_control:
				input_left = true;
			if mouse_offset.y > 1 and y_control:
				input_down = true;
			if mouse_offset.y < -1 and y_control:
				input_up = true;
		
		# Figure out movement to do this tick
		var move_speed = base_move_speed * 2 if anti_mode else base_move_speed;
		var movement := Vector2(0, 0);
		if input_left:
			movement.x += clamp(-move_speed, left_barrier - position.x, 0);
		if input_right:
			movement.x += clamp(move_speed, 0, right_barrier - position.x);
		if input_up:
			movement.y += clamp(-move_speed, top_barrier - position.y, 0);
		if input_down:
			movement.y += clamp(move_speed, 0, bottom_barrier - position.y);
		
		# Do movement, with aura center lagging behind
		position += movement;
		aura_center -= movement;
	
	# Slowly bring aura_center back towards core
	aura_center.x *= 0.8;
	aura_center.y *= 0.8;
	
	# Aura resizing
	aura_radius = move_toward(aura_radius, aura_radius_desired, 0.25);
	
	# Clamp aura offset so it doesn't drift too far from center
	if aura_radius > 3:
		aura_center.x = clamp(aura_center.x, -(aura_radius - 3), aura_radius - 3);
		aura_center.y = clamp(aura_center.y, -(aura_radius - 3), aura_radius - 3);
	else:
		aura_center = Vector2();
	
	# Update well area position & radius
	$WellArea.position = aura_center.round();
	$WellArea/Circle.shape.radius = aura_radius;
	
	# Pull all things within the gravity well
	for area in $WellArea.get_overlapping_areas():
		var dust = area.get_owner() as Dust;
		var shard = area.get_owner() as Shard;
		if dust:
			var offset = position - dust.position;
			var pull_strength = 100.0 / (offset.length() * offset.length());
			pull_strength = clamp(pull_strength, 0.1, 1.0);
			dust.velocity += offset.normalized() * pull_strength;
			dust.velocity *= 0.98;
			dust.velocity_changed();
		elif shard:
			var offset = position - shard.position;
			var pull_strength = 50.0 / (offset.length() * offset.length());
			pull_strength = clamp(pull_strength, 0.1, 0.5);
			shard.velocity += offset.normalized() * pull_strength;
			shard.velocity *= 0.99;
			shard.pull_time += 1;
			if shard.pull_time == shard.CHARGE_DELAY + 1:
				orbiting += 1;
			shard.velocity_changed();
	
	# Queue a redraw
	queue_redraw();

func _draw():
	# Draw pulse 1
	var pulse_position = lerp(aura_center, Vector2(), aura_pulse_factor);
	var pulse_radius = lerp(aura_radius, 3.0, aura_pulse_factor);
	draw_arc(pulse_position.round(), pulse_radius, 0, TAU, 24, Color.hex(0x12121244), 1, false);
	# Draw pulse 2
	pulse_position = lerp(aura_center, Vector2(), wrap(aura_pulse_factor + 0.5, 0, 1.0));
	pulse_radius = lerp(aura_radius, 3.0, wrap(aura_pulse_factor + 0.5, 0, 1.0));
	draw_arc(pulse_position.round(), pulse_radius, 0, TAU, 24, Color.hex(0x12121244), 1, false);
	
	# Draw base aura circle
	draw_arc(aura_center.round(), aura_radius-0.5, 0, TAU, 24, Color.hex(0x231d26ff), 1, false);
	draw_arc(aura_center.round(), aura_radius, 0, TAU, 24, Color.hex(0x847e87ff), 1, false);

func _on_entered_well_area(area):
	# Only consider charged shards as orbiting
	var shard = area.get_owner() as Shard;
	if shard and shard.pull_time > shard.CHARGE_DELAY:
		orbiting += 1;

func _on_exited_well_area(area):
	var shard = area.get_owner() as Shard;
	if shard and shard.pull_time > shard.CHARGE_DELAY:
		orbiting -= 1;

func _on_entered_core_area(area):
	var dust = area.get_owner() as Dust;
	var shard = area.get_owner() as Shard;
	if dust:
		if not anti_mode and controlled:
			aura_radius_desired = clamp(aura_radius_desired + (aura_max - aura_min) / 100.0, aura_min, aura_max);
		absorbed.emit(dust);
	if shard:
		fractured.emit(shard);

func die():
	dead = true;
	controlled = false;
	# Also reset for next life;
	aura_radius = 2;
	aura_radius_desired = 2;
	aura_center = Vector2(0, 0);
	anti_mode = false;
