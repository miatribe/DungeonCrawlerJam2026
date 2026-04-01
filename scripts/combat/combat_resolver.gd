extends RefCounted
class_name CombatResolver

const MIN_HIT_CHANCE := 5
const MAX_HIT_CHANCE := 95
const BASE_HIT_CHANCE := 70
const BASE_CRIT_CHANCE := 5
const MAX_CRIT_CHANCE := 50
const CRIT_MULTIPLIER := 1.5

static func resolve_attack(attacker_stats: CombatStats, defender_stats: CombatStats, rng: RandomNumberGenerator = null) -> CombatResult:
	var result := CombatResult.new()
	if attacker_stats == null or defender_stats == null:
		return result

	var local_rng := rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()

	var attacker_attack := maxi(0, attacker_stats.attack)
	var attacker_hit := maxi(0, attacker_stats.hit)
	var defender_defense := maxi(0, defender_stats.defense)
	var defender_dodge := maxi(0, defender_stats.dodge)

	result.hit_chance = clampi(BASE_HIT_CHANCE + attacker_hit - defender_dodge, MIN_HIT_CHANCE, MAX_HIT_CHANCE)
	result.hit_roll = local_rng.randi_range(1, 100)
	if result.hit_roll > result.hit_chance:
		return result

	result.hit = true
	if attacker_attack <= 0:
		result.damage = 0
		return result
	var base_damage := maxi(1, attacker_attack - defender_defense)
	var variance := local_rng.randi_range(-2, 2)
	result.damage = maxi(1, base_damage + variance)

	result.crit_chance = clampi(BASE_CRIT_CHANCE + int((attacker_hit - defender_dodge) / 2), 0, MAX_CRIT_CHANCE)
	result.crit_roll = local_rng.randi_range(1, 100)
	if result.crit_roll <= result.crit_chance:
		result.crit = true
		result.damage = maxi(1, int(ceil(result.damage * CRIT_MULTIPLIER)))

	return result
