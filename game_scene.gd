extends Node2D

# Game rules
var ticks_per_second: int = 30;
var tick_timer: float = 0;

# Area rules
var dust_density: float = 0.1;
var shard_percentage: float = 0.0;

# Mass stuff
var mass_count: int = 0;

# Multiplier stuff
var multiplier: int = 1;
var multiplier_progress: int = 0;
var multiplier_shield: int = 0;

# Score stuff
var total_score: int = 0;
var total_score_display_value: int = 0;

# Gameplay control
var prepping := true;
var playing := false;
var results := false;

# Other visual controls
var hit_freeze: float = 0;
var shake_time: float = 0;
var flicker_time = {}

func _ready():
	# Set up some stuff
	$Well.right_barrier = $Barrier.position.x - 3;
	flicker_time["Passthrough"] = 0;
	flicker_time["MultiArrow"] = 0
	
func _process(delta):
	# Screen shake control
	if shake_time > 0:
		shake_time = move_toward(shake_time, 0, delta);
		position = Vector2(randf() * 2 - 1,randf() * 2 - 1);
	else:
		position = Vector2();
	
	# Freeze control, then tick
	if hit_freeze > 0:
		hit_freeze = move_toward(hit_freeze, 0, delta);
	else:
		# Game state control
		if playing and $Well.dead:
			end_game();
		if Input.is_physical_key_pressed(KEY_SPACE) and (prepping or results):
			start_game();
		
		# Decide when to tick
		tick_timer += delta;
		while tick_timer > 1.0 / ticks_per_second:
			tick_timer -= 1.0 / ticks_per_second;
			tick();

func tick():
	# Debug
	if Input.is_physical_key_pressed(KEY_1):
		var new_dust = preload("res://dust.tscn").instantiate();
		$Dust.add_child(new_dust);
		new_dust.position = $Well.position;
	
	# Tick flicker times
	for light in flicker_time:
		flicker_time[light] = move_toward(flicker_time[light], 0, 1);
	
	# Multiplier decay
	if multiplier_shield > 0:
		multiplier_shield = move_toward(multiplier_shield, 0, clamp(floor(multiplier * 0.5) + 1, 1, 10));
	else:
		multiplier_progress = move_toward(multiplier_progress, 0, 1);
		if playing and multiplier_progress <= 0 and multiplier > 1:
			multiplier -= 1;
			multiplier_progress = 99;
	
	# Tick the gravity well
	$Well.tick();
	
	# Tick all dust
	for dust in $Dust.get_children():
		dust.tick();
		# Clean up dust that's drifted
		if dust.position.x < -100 or dust.position.x > 340:
			dust.queue_free();
		if dust.position.y < -100 or dust.position.y > 235:
			dust.queue_free();
	
	# Create new dust
	if randf() <= dust_density:
		if randf() <= shard_percentage:
			var new_shard = preload("res://shard.tscn").instantiate();
			$Dust.add_child(new_shard);
			new_shard.position = Vector2(250, randf() * 135);
			new_shard.velocity = Vector2(lerp(-1, -2, randf()), lerp(-0.2, 0.2, randf()));
			new_shard.velocity_changed();
		else:
			var new_dust = preload("res://dust.tscn").instantiate();
			$Dust.add_child(new_dust);
			new_dust.position = Vector2(250, randf() * 135);
			new_dust.velocity = Vector2(lerp(-1, -2, randf()), lerp(-0.2, 0.2, randf()));
			new_dust.velocity_changed();
	
	# Fade in the barrier when nearby
	$Barrier.modulate.a = clamp(($Well.position.x - $Barrier.position.x + 10) / 10.0, 0.02, 1) if playing else 0;
	$Barrier.position.y += 1;
	if $Barrier.position.y > 4:
		$Barrier.position.y = 0;
	
	# Multiplier growth from satellites, only when multiplier is shielded
	if $Well.orbiting > 0 and multiplier_shield > 0:
		multiplier_progress += $Well.orbiting;
		if multiplier_progress >= 100:
			multiplier += 1;
			multiplier_progress = 1;
			multiplier_shield = 100;
			flicker_time["MultiArrow"] = 25;
	
	# Update score
	var score_increment = ceil(abs(total_score - total_score_display_value) / 10.0);
	total_score_display_value = move_toward(total_score_display_value, total_score, score_increment);
	
	# Update the hud display
	update_display();

func start_game():
	# Game state change
	prepping = false;
	results = false;
	playing = true;
	
	# Reset player
	$Well.position = Vector2(30, 79);
	$Well.dead = false;
	$Well.controlled = true;
	
	# Reset area
	dust_density = 0.1;
	shard_percentage = 0.1;
	
	# Reset hud
	mass_count = 0;
	multiplier = 1;
	multiplier_progress = 0;
	multiplier_shield = 0;
	total_score = 0;
	total_score_display_value = 0;

func end_game():
	# Game state change
	playing = false;
	results = true;
	
	# Move player far off screen
	var explosion_position = $Well.position;
	$Well.position.x = -500;
	
	# Create particle explosion
	for i in range(100):
		var new_dust = preload("res://dust.tscn").instantiate();
		$Dust.add_child(new_dust);
		new_dust.position = explosion_position;
		new_dust.velocity = Vector2(lerp(-4.0, 4.0, randf()), lerp(-4.0, 4.0, randf()));
		new_dust.velocity_changed();
	
	# Update displays
	mass_count = 0;

func update_display():
	# Update anti-mode warning light
	# It flashes whenever dust will be insta-transmitted
	if $Well.anti_mode or mass_count == 99:
		$TopHud/AntiModeLight.visible = Time.get_ticks_msec() % 1000 < 500;
	else:
		$TopHud/AntiModeLight.visible = false;
	
	# Update size bar display and mass count display
	if $Well.anti_mode:
		$TopHud/SizeMeter.frame = 0;
		$TopHud/MassDigit0.frame = 11;
		$TopHud/MassDigit1.frame = 11;
	else:
		if mass_count == 99:
			$TopHud/SizeMeter.frame = 11;
		else:
			var size_factor = mass_count / 100.0
			$TopHud/SizeMeter.frame = lerp(1, 11, size_factor);
		update_number_display("Mass", mass_count);
	
	# Update multiplier shield display
	if multiplier_shield > 0:
		$TopHud/MultiShieldBar.visible = true;
		$TopHud/MultiShieldBar.frame = 0;
		$TopHud/MultiShieldBar.scale.x = round(multiplier_shield * 17.0 / 100.0);
	elif (multiplier > 1 and playing) or multiplier_progress > 0:
		# Flash red if multiplier is actively decaying
		$TopHud/MultiShieldBar.visible = Time.get_ticks_msec() % 300 < 150;
		$TopHud/MultiShieldBar.frame = 1;
		$TopHud/MultiShieldBar.scale.x = 17.0;
	else:
		$TopHud/MultiShieldBar.visible = false;
	
	# Update multiplier builder lights
	$TopHud/MultiBuilderLights.frame = $Well.orbiting;
	
	# Update multiplier bar
	if multiplier_progress > 0:
		$TopHud/MultiBar.visible = true;
		$TopHud/MultiBar.region_rect.size.x = 2 + round(227 * multiplier_progress / 100.0);
	else:
		$TopHud/MultiBar.visible = false;
	
	# Update multiplier display
	update_number_display("Mult", multiplier);
	
	# Update total score display
	update_number_display("Score", total_score_display_value);
	
	# Update lights from flicker control
	$TopHud/MultiArrowLight.visible = Time.get_ticks_msec() % 200 < 100 if flicker_time["MultiArrow"] > 0 else false;
	$TopHud/PassthroughLight.visible = flicker_time["Passthrough"] > 0;

func update_number_display(display_id: String, value: int):
	var digits = 9 if display_id == "Score" else 2;
	for i in range(digits):
		var digit = $TopHud.get_node(display_id + "Digit" + str(i));
		if value == 0 and i != 0:
			digit.frame = 10;
		else:
			digit.frame = value % 10;
			value /= 10;

func _on_well_absorbed(dust):
	if playing:
		if not $Well.anti_mode and mass_count < 99:
			mass_count += 1;
		else:
			# Do insta-transmit
			total_score += 1;
			flicker_time["Passthrough"] = 3;
		
		# Shield current multiplier for collecting dust
		multiplier_shield = 100;
	
	# Destroy the dust
	dust.queue_free();

func _on_well_fractured(shard):
	shard.queue_free();
	hit_freeze = 0.5;
	shake_time = 0.25;
	$Well.die();

func _on_transmit_mass():
	total_score += mass_count * multiplier;
	mass_count = 0;
	multiplier = 1;
	# TODO: Make a better scoring animation, this should feel good at high numbers!
