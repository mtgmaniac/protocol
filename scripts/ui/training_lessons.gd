extends RefCounted

# The drill rigs inputs, never damage or HP. Open beats accept normal play.
static func core() -> Array:
	return [
		{"fullscreen": true, "title": "TRAINING", "text": "Select units using their dice or portraits. Hold a portrait to inspect abilities."},
		{"targets": ["roll_button"], "text": "Roll one die for every unit.", "advance": "roll_pressed"},
		{"hide_coach": true, "advance": "rolled"},
		{"targets": ["card:combat", "die:combat"], "separate": true, "text": "Higher is not always better. Hold Strike's portrait to inspect its abilities.", "advance": "inspected", "inspect_hero": "combat"},
		{"targets": ["enemy_pip", "enemy_die"], "separate": true, "text": "The drone plans 7 damage to Strike. Your squad acts first."},
		{"targets": ["card:combat", "die:combat"], "separate": true, "title": "MARK", "glyph": "mark", "text": "The next hit deals 50% more damage. Select Strike, then the drone.", "advance": "assigned", "hero": "combat"},
		{"targets": ["card:engineer", "die:engineer"], "separate": true, "text": "Engineer deals 10 damage. After Mark, that becomes 15. Target the drone.", "advance": "assigned", "hero": "engineer"},
		{"targets": ["card:medic", "die:medic"], "separate": true, "text": "Medic grants 3 heal and 3 shield. Target Strike to absorb incoming damage.", "advance": "assigned", "hero": "medic", "target_hero": "combat"},
		{"targets": ["roll_button"], "text": "All three heroes are assigned. They act in numbered order. End the turn.", "advance": "turn_resolved", "round": 1},
		{"targets": ["card:combat", "protocol_value"], "separate": true, "text": "Mark raised 10 damage to 15. Shields absorb before HP. You earned 1 Protocol."},
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
		{"fullscreen": true, "title": "NEXT BATTLE", "text": "Two enemies this time. Pulse replaces Strike to demonstrate burn. Your chosen item is in Items."},
		{"targets": ["roll_button"], "text": "Roll to see your options. Protocol starts at 0 each battle.", "advance": "roll_pressed"},
		{"hide_coach": true, "advance": "rolled"},
		{"targets": ["ability:pulse", "die:pulse"], "separate": true, "title": "BURN", "glyph": "burn", "text": "Pulse deals 9 damage now, then 3 burn damage at the end of the next turn."},
		{"fullscreen": true, "title": "CHOOSE YOUR PLAN", "text": "Concentrate attacks or split targets. Choose who needs Medic's protection."},
		{"hide_coach": true, "advance": "turn_resolved", "free": true},
		{"targets": ["item", "protocol_value"], "separate": true, "title": "USE AN ITEM", "text": "You earned 1 Protocol. After rolling, open Items to use your reward. Items cost 1 Protocol and are consumed."},
		{"fullscreen": true, "text": "Burn remains on its target for this turn. Watch its damage resolve, then finish the battle."},
		{"fullscreen": true, "hide_coach": true, "free": true, "advance": "won"},
		{"fullscreen": true, "title": "TRAINING COMPLETE", "text": "New effects explain themselves when first encountered. Help keeps the reference. Training rewards stay here.", "advance": "tap_finish"},
	]
