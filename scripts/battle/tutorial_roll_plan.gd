extends RefCounted

# Kev's approved schedule. One-based battle and round numbers. Empty means free.
# This plan is also consumed by the outcome simulator before runtime integration.
static func heroes(battle: int, round_number: int) -> Dictionary:
	if battle == 1:
		if round_number == 1:
			return {"combat": 9, "engineer": 12, "medic": 2}
		if round_number == 2:
			return {"combat": 8, "engineer": 6, "medic": 3}
	elif battle == 2 and round_number == 1:
		return {"combat": 3, "pulse": 4, "medic": 3}
	return {}


static func enemy_value(battle: int, round_number: int) -> int:
	return 6 if not heroes(battle, round_number).is_empty() else 0
