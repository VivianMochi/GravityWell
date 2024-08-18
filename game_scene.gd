extends Node2D

var ticks_per_second: int = 30;
var tick_timer: float = 0;

var dust_density: float = 0.2;
var shard_percentage: float = 0.1;

var mass_count: int = 0;
var multiplier: int = 1;
var total_score: int = 0;
var total_score_display_value: int = 0;

func _ready():
	# Set up some stuff
	$Well.right_barrier = $Barrier.position.x - 3;

func _process(delta):
	# Decide when to tick
	tick_timer += delta;
	while tick_timer > 1.0 / ticks_per_second:
		tick_timer -= 1.0 / ticks_per_second;
		tick();

func tick():
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
	$Barrier.modulate.a = clamp(($Well.position.x - $Barrier.position.x + 10) / 10.0, 0.05, 1);
	$Barrier.position.y += 1;
	if $Barrier.position.y > 4:
		$Barrier.position.y = 0;
	
	# Update display
	total_score_display_value = move_toward(total_score_display_value, total_score, 2);
	update_display();

func update_display():
	# Update size bar display and mass count display
	if $Well.anti_mode:
		$TopHud/AntiModeLight.visible = Time.get_ticks_msec() % 1000 < 500;
		$TopHud/SizeMeter.frame = 0;
		$TopHud/MassDigit0.frame = 11;
		$TopHud/MassDigit1.frame = 11;
	else:
		if mass_count == 99:
			$TopHud/SizeMeter.frame = 11;
		else:
			var size_factor = mass_count / 100.0
			$TopHud/SizeMeter.frame = lerp(1, 11, size_factor);
		$TopHud/AntiModeLight.visible = false;
		update_number_display("Mass", mass_count);
	
	# Update multiplier display
	update_number_display("Mult", multiplier);
	
	# Update total score display
	update_number_display("Score", total_score_display_value);

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
	if not $Well.anti_mode:
		if mass_count < 99:
			mass_count += 1;
		else:
			# Do mass burn-through here
			pass
		$Well.grow_for_mass(mass_count);
	dust.queue_free();

func _on_well_fractured(shard):
	shard.queue_free();
	# Reset game here
	total_score = 0;

func _on_transmit_mass():
	total_score += mass_count * multiplier;
	mass_count = 0;
	multiplier = 1;
