extends RefCounted

# The drill rigs inputs, never damage or HP. Open beats accept normal play.
static func core() -> Array:
	return [
		{"fullscreen": true, "title": "WELCOME", "text": "Welcome to Overload Protocol. Let us show you around with a short training battle."},
		{"fullscreen": true, "title": "TRAINING", "text": "Select units using their dice or portraits. Hold a portrait to inspect abilities."},
		{"targets": ["roll_button"], "text": "Roll one die for every unit.", "advance": "roll_pressed"},
		{"hide_coach": true, "advance": "rolled"},
		{"targets": ["card:combat", "die:combat"], "separate": true, "text": "Higher is not always better. Hold Strike's portrait to inspect its abilities.", "advance": "inspected", "inspect_hero": "combat"},
		{"targets": ["enemy_pip", "enemy_die"], "separate": true, "text": "The drone plans 7 damage to Strike. Your squad acts first."},
		{"targets": ["card:combat", "die:combat"], "separate": true, "title": "DAMAGE", "glyph": "damage", "text": "Strike deals 6 damage. Select its die or portrait, then the drone's die or portrait.", "advance": "assigned", "hero": "combat"},
		{"targets": ["card:engineer", "die:engineer"], "separate": true, "text": "Engineer deals 10 damage. Select Engineer, then target the drone.", "advance": "assigned", "hero": "engineer"},
		{"targets": ["card:medic", "die:medic"], "separate": true, "text": "Medic grants 3 heal and 3 shield. Target Strike to absorb incoming damage.", "advance": "assigned", "hero": "medic", "target_hero": "combat"},
		{"targets": ["roll_button"], "text": "All three heroes are assigned. They act in numbered order. End the turn.", "advance": "turn_resolved", "round": 1},
		{"targets": ["card:combat", "protocol_value"], "separate": true, "text": "Your attacks dealt 16 damage. Shields absorb damage before HP. You earned 1 Protocol."},
		{"targets": ["roll_button"], "text": "Roll to see your next choices.", "advance": "roll_pressed"},
		{"hide_coach": true, "advance": "rolled"},
		{"targets": ["nudge"], "text": "Nudge costs 1 Protocol and raises a die by 3. Tap the arrow.", "armed_text": "Select Strike's die: 8 becomes 11, changing 6 damage to 10.", "advance": "nudged", "hero": "combat"},
		{"targets": ["card:combat", "die:combat"], "separate": true, "text": "Select Strike's new 10-damage attack, then target the drone.", "advance": "assigned", "hero": "combat"},
		{"targets": ["card:engineer", "die:engineer"], "separate": true, "text": "This roll gives Engineer 9 shield. Protect Strike.", "advance": "assigned", "hero": "engineer", "target_hero": "combat"},
		{"targets": ["card:medic", "die:medic"], "separate": true, "text": "Select Medic, then heal Strike.", "advance": "assigned", "hero": "medic", "target_hero": "combat"},
		{"targets": ["roll_button"], "text": "Your attack, shield and heal are ready. End the turn.", "advance": "turn_resolved", "round": 2},
		{"fullscreen": true, "title": "YOUR TURN", "text": "Finish the drone. Choose your targets and order; spend Protocol if useful. Hold portraits for help."},
		{"fullscreen": true, "hide_coach": true, "free": true, "advance": "won"},
		{"fullscreen": true, "title": "BATTLE COMPLETE", "text": "Choose an item next. You can then keep training or start your run.", "advance": "tap_finish"},
	]

static func practice() -> Array:
	return [
		{"fullscreen": true, "title": "NEXT BATTLE", "text": "Two enemies this time. Pulse replaces Engineer so we can try Mark and Burn. Your chosen item is in your inventory."},
		{"targets": ["roll_button"], "text": "Roll to see your options.", "advance": "roll_pressed"},
		{"hide_coach": true, "advance": "rolled"},
		{"targets": ["card:combat", "die:combat"], "separate": true, "title": "MARK", "glyph": "mark", "text": "Mark makes the next hit deal 50% more damage. Select Strike, then choose a drone.", "advance": "assigned", "hero": "combat"},
		{"targets": ["ability:pulse", "die:pulse"], "separate": true, "title": "BURN", "glyph": "burn", "text": "Pulse deals 6 damage and applies 2 Burn for 1 turn. Target the same drone: Mark raises the hit to 9.", "advance": "assigned", "hero": "pulse"},
		{"fullscreen": true, "title": "PROTECT YOUR SQUAD", "text": "Choose who needs Medic's heal and shield, then end the turn. Burn deals its damage at the end of the next turn."},
		{"hide_coach": true, "advance": "turn_resolved", "free": true},
		{"targets": ["item"], "title": "USE AN ITEM", "text": "After rolling, open your inventory to use your reward. Using an item costs 1 Protocol and consumes it."},
		{"fullscreen": true, "title": "YOUR PLAN", "text": "Choose your targets and attack order. Spend Protocol if useful. Watch Burn deal damage at the end of this turn."},
		{"fullscreen": true, "hide_coach": true, "free": true, "advance": "won"},
		{"fullscreen": true, "title": "MORE TO DISCOVER", "text": "You learned Mark and Burn, two of many effects. Hold portraits to inspect abilities, or open Help for a reference."},
		{"fullscreen": true, "title": "TRAINING COMPLETE", "text": "Thanks for training. Now select your squad and begin your run!", "advance": "tap_finish"},
	]
