extends Node2D

# Game rules
var ticks_per_second: int = 30;
var tick_timer: float = 0;

# Area rules
var wave: int = 0;
var ticks_since_start: int = 0;
var dust_density: float = 0.1;
var shard_percentage: float = 0.0;
var kill_grace: int = 0;

# Mass stuff
var mass_count: int = 0;

# Multiplier stuff
var multiplier: int = 1;
var multiplier_progress: int = 0;
var multiplier_shield: int = 0;
var frenzy_time: int = 0;
var frenzy_time_start: int = 0;

# Score stuff
var total_score: int = 0;
var total_score_display_value: int = 0;

# Hidden score
var kills: int = 0;

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
	flicker_time["MultiArrow"] = 0;
	flicker_time["MaxMulti"] = 0;
	flicker_time["Multi"] = 0;
	flicker_time["Transmit"] = 0;
	
	$BeatMusic.volume_db = linear_to_db(0.0);

func _input(event):
	# Music control
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			if $MenuMusic.playing:
				$MenuMusic.stop();
				$BeatMusic.stop();
			else:
				$MenuMusic.play();
				$BeatMusic.play();

func _process(delta):
	# Screen shake control
	if shake_time > 0:
		shake_time = move_toward(shake_time, 0, delta);
		position = Vector2(randf() * 2 - 1,randf() * 2 - 1);
	else:
		position = Vector2();
	
	# Control volume
	if hit_freeze > 0:
		$OrbitingSound.volume_db = linear_to_db(0.0);
	else:
		$OrbitingSound.volume_db = linear_to_db(1.0 if $Well.orbiting > 3 else $Well.orbiting * 0.3)
	
	# Freeze control, then tick
	if hit_freeze > 0:
		hit_freeze = move_toward(hit_freeze, 0, delta);
	else:
		# Game state control
		if playing and $Well.dead:
			end_game();
		if (Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and (prepping or results):
			start_game();
		
		# Decide when to tick
		tick_timer += delta;
		while tick_timer > 1.0 / ticks_per_second:
			tick_timer -= 1.0 / ticks_per_second;
			tick();

func tick():
	ticks_since_start += 1;
	
	# Gameplay control
	if shard_percentage < 0.01 and mass_count >= 10:
		shard_percentage = 0.01;
	if dust_density < 0.2 and mass_count >= 99:
		dust_density = 0.2;
	
	kill_grace = move_toward(kill_grace, 0, 1);
	
	# Start the first wave after getting +1 multiplier
	if kills == 0 and wave == 0 and multiplier > 1:
		next_wave();
	# Start a new wave when all enemies are killed
	elif kills > 0 and $Enemies.get_children().size() == 0:
		next_wave();
	
	# Debug keys
	var debug_enabled = false;
	if debug_enabled and Input.is_physical_key_pressed(KEY_1):
		var new_dust = preload("res://dust.tscn").instantiate();
		$Dust.add_child(new_dust);
		new_dust.position = $Well.position;
	if debug_enabled and Input.is_physical_key_pressed(KEY_2):
		multiplier = move_toward(multiplier, 99, 1);
	if debug_enabled and Input.is_physical_key_pressed(KEY_3):
		if not $Enemies.get_children().is_empty():
			$Enemies.get_children()[0].explode.emit(1);
	
	# Tick flicker times
	for light in flicker_time:
		flicker_time[light] = move_toward(flicker_time[light], 0, 1);
	
	# Multiplier decay
	if multiplier_shield > 0:
		multiplier_shield = move_toward(multiplier_shield, 0, clamp(round(multiplier * 0.1) + 1, 1, 10));
	else:
		multiplier_progress = move_toward(multiplier_progress, 0, 1);
		if playing and multiplier_progress <= 0 and multiplier > 1:
			multiplier -= 1;
			multiplier_progress = 99;
	
	# Tick the gravity well
	$Well.tick();
	
	# Tick enemies
	for enemy in $Enemies.get_children():
		enemy.tick();
	
	# Tick all dust
	for dust in $Dust.get_children():
		if dust is Dust and dust.homing:
			dust.velocity += ($Well.position - dust.position).normalized() * 0.05;
			dust.velocity *= 0.98;
			dust.velocity_changed();
		dust.tick();
		# Clean up dust that's drifted
		if dust.position.x < -100 or dust.position.x > 340:
			dust.queue_free();
		if dust.position.y < -100 or dust.position.y > 235:
			dust.queue_free();
		if dust is Shard and dust.pull_time == dust.CHARGE_DELAY:
			$ChargeSound.play();
	
	# Create new dust
	if randf() <= dust_density:
		var new_dust = preload("res://dust.tscn").instantiate();
		$Dust.add_child(new_dust);
		new_dust.position = Vector2(250, 25 + randf() * 110);
		new_dust.velocity = Vector2(lerp(-1, -2, randf()), lerp(-0.2, 0.2, randf()));
		new_dust.velocity_changed();
	if kill_grace == 0 and randf() <= (shard_percentage if mass_count > 50 else shard_percentage * 2.0):
		var new_shard = preload("res://shard.tscn").instantiate();
		$Dust.add_child(new_shard);
		new_shard.position = Vector2(250, 25 + randf() * 110);
		new_shard.velocity = Vector2(lerp(-1, -2, randf()), lerp(-0.2, 0.2, randf()));
		new_shard.velocity_changed();
	
	# Fade in the barrier when nearby
	$Barrier.modulate.a = clamp(($Well.position.x - $Barrier.position.x + 10) / 10.0, 0.02, 1) if playing else 0;
	$Barrier.position.y += 1;
	if $Barrier.position.y > 4:
		$Barrier.position.y = 0;
	
	# Frenzy control
	if frenzy_time > 0:
		frenzy_time -= 1;
		multiplier_progress += 5;
		multiplier_shield = 100;
	
	# Multiplier growth from satellites, only when multiplier is shielded
	if $Well.orbiting > 0 and multiplier_shield > 0:
		multiplier_progress += $Well.orbiting;
	
	if multiplier_progress >= 100:
		if multiplier < 99:
			multiplier += 1;
			multiplier_progress = 1;
			multiplier_shield = 100;
			flicker_time["MultiArrow"] = 25;
		else:
			# Burn multiplier into score for being maxxed
			total_score += multiplier_progress - 100;
			multiplier_progress = 100;
			flicker_time["MaxMulti"] = 10;
	
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
	
	# Sound
	#$MenuMusic.playing = false;
	$TargetHitSound.play();
	
	# Reset player
	$Well.position = Vector2(30, 79);
	$Well.dead = false;
	$Well.controlled = true;
	
	# Reset area
	wave = 0;
	ticks_since_start = 0;
	# These feel better as "unlocks"
	#dust_density = 0.1;
	#shard_percentage = 0.0;
	
	# Reset hud
	mass_count = 0;
	multiplier = 1;
	multiplier_progress = 0;
	multiplier_shield = 0;
	frenzy_time = 0;
	total_score = 0;
	total_score_display_value = 0;
	kills = 0;
	
	# Destroy all enemies cleanly
	for enemy in $Enemies.get_children():
		enemy.queue_free();

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
	
	# Sound
	$ExplosionSound.play();
	
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
	if frenzy_time > 0:
		$TopHud/MultiShieldBar.visible = true;
		$TopHud/MultiShieldBar.frame = 2;
		$TopHud/MultiShieldBar.scale.x = 17.0 * frenzy_time / frenzy_time_start;
	elif multiplier_shield > 0:
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
	
	# Update a few multiplier related lights
	$TopHud/MultiBuilderLights.frame = clamp($Well.orbiting, 0, 10);
	$TopHud/MultiArrowLight.frame = 1 if frenzy_time > 0 else 0;
	$TopHud/MaxMultiLight.frame = 1 if frenzy_time > 0 else 0;
	
	# Update multiplier bar
	if multiplier_progress > 0:
		$TopHud/MultiBar.visible = true;
		$TopHud/MultiBar.region_rect.size.x = 2 + round(227 * multiplier_progress / 100.0);
		$TopHud/MultiBar.region_rect.position.y = 6 if frenzy_time > 0 else 0;
	else:
		$TopHud/MultiBar.visible = false;
	
	# Update multiplier display
	update_number_display("Mult", multiplier);
	
	# Update total score display
	update_number_display("Score", total_score_display_value);
	
	# Update lights from flicker control
	$TopHud/MultiArrowLight.visible = Time.get_ticks_msec() % 200 < 100 if flicker_time["MultiArrow"] > 0 else false;
	$TopHud/PassthroughLight.visible = flicker_time["Passthrough"] > 0;
	$TopHud/MaxMultiLight.visible = Time.get_ticks_msec() % 100 < 50 if flicker_time["MaxMulti"] > 0 else false;
	$TopHud/MultiLight.visible = Time.get_ticks_msec() % 200 < 100 if flicker_time["Multi"] > 0 else false;
	$TopHud/TransmitLight.visible = Time.get_ticks_msec() % 200 < 100 if flicker_time["Transmit"] > 0 else false;

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
	
	# Sounds
	$CollectSound.pitch_scale = 0.7 + mass_count * 0.3 / 99.0;
	$CollectSound.play();
	if mass_count == 99:
		$CollectSoundFull.play();

func _on_well_fractured(shard):
	if shard.empowered:
		shard.queue_free();
		frenzy_time_start = 100 * shard.empower_level;
		frenzy_time = frenzy_time_start;
		for dust in $Dust.get_children():
			if dust is Dust:
				dust.homing = true;
	else:
		hit_freeze = 0.5;
		shake_time = 0.25;
		$Well.die();

func _on_transmit_mass():
	if mass_count > 0:
		# Do transmit animations
		flicker_time["Transmit"] = 35;
		if multiplier > 1:
			flicker_time["Multi"] = 35;
		
		# Sound
		$TransmitSound.volume_db = linear_to_db(0.5 + mass_count * 0.5 / 99.0);
		$TransmitSound.play();
		
		# Score
		total_score += mass_count * multiplier;
		mass_count = 0;
		# Should multiplier reset here?
		# I like the act of trying to rebuild your mass while your multiplier is decaying!
		#multiplier = 1;

func next_wave():
	wave += 1;
	var enemy_count = 1;
	for i in range(enemy_count):
		var new_enemy = preload("res://target.tscn").instantiate();
		$Enemies.add_child(new_enemy);
		new_enemy.generate_move_logic(1 if wave <= 3 else 2, 100);
		if wave == 1:
			new_enemy.patrol_points[0] = Vector2(200, 79);
		new_enemy.explode.connect(_on_enemy_exploded.bind(new_enemy));

func _on_enemy_exploded(empower_level, enemy):
	# Create the empowered drop
	var new_shard = preload("res://shard.tscn").instantiate();
	$Dust.add_child.call_deferred(new_shard);
	new_shard.position = enemy.position;
	new_shard.empowered = true;
	new_shard.empower_level = empower_level;
	new_shard.CHARGE_DELAY = -1;
	new_shard.velocity = Vector2(-0.6, lerp(-0.2, 0.2, randf()));
	new_shard.velocity_changed();
	
	# Hit sound
	$TargetHitSound.pitch_scale = 0.9 + empower_level * 0.1;
	$TargetHitSound.play();
	$BeatMusic.volume_db = linear_to_db(0.5);
	
	# Create explosion
	for i in range(99):
		var new_dust = preload("res://dust.tscn").instantiate();
		$Dust.add_child.call_deferred(new_dust);
		new_dust.position = enemy.position;
		new_dust.homing = true;
		new_dust.velocity = Vector2(lerp(-4.0, 4.0, randf()), lerp(-4.0, 4.0, randf()));
		new_dust.velocity_changed();
	
	# Delete the enemy
	enemy.queue_free();
	
	# Register the kill
	kills += 1;
	kill_grace = 90;

func _on_well_empowered_pulse(shard):
	for i in range(5 * shard.empower_level):
		var new_dust = preload("res://dust.tscn").instantiate();
		$Dust.add_child.call_deferred(new_dust);
		new_dust.position = shard.position;
		new_dust.homing = true;
		new_dust.velocity = Vector2(lerp(-1.0, 1.0, randf()), lerp(-1.0, 1.0, randf())) + shard.velocity;
		new_dust.velocity_changed();

func _on_menu_music_finished():
	$MenuMusic.play();
	$BeatMusic.play();

func _on_orbiting_sound_finished():
	$OrbitingSound.play();

func _on_beat_music_finished():
	$BeatMusic.volume_db = linear_to_db(clamp(db_to_linear($BeatMusic.volume_db) - 0.1, 0, 1.0));
	$BeatMusic.play();
