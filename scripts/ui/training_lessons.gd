extends RefCounted

# The drill rigs inputs, never damage or HP. Open beats accept normal play.
static func core() -> Array:
	return [
		{"fullscreen": true, "title": "WELCOME", "text": "Welcome to Overload Protocol. Let us show you around with a short training battle."},
		{"fullscreen": true, "title": "TRAINING", "text": "Your squad is at the bottom. Enemies are at the top."},
		{"targets": ["roll_button"], "text": "Press Roll in the center to roll one die for each unit.", "advance": "roll_pressed"},
		{"hide_coach": true, "advance": "rolled"},
		{"targets": ["ability:combat", "card:combat", "die:combat"], "separate": true, "text": "Strike rolled 9. Its ability is shown here. Hold Strike's portrait to see all its abilities.", "advance": "inspected", "inspect_hero": "combat"},
		{"targets": ["enemy_pip", "enemy_die"], "separate": true, "text": "Enemies show their next action here. SCRAP plans to deal 7 damage to Strike."},
		{"targets": ["card:combat", "die:combat"], "separate": true, "title": "DAMAGE", "glyph": "damage", "text": "Strike deals 6 damage. Select its die or portrait, then SCRAP's die or portrait.", "advance": "assigned", "hero": "combat"},
		{"targets": ["card:engineer", "die:engineer"], "separate": true, "text": "Engineer deals 10 damage. Select Engineer, then target SCRAP.", "advance": "assigned", "hero": "engineer"},
		{"targets": ["card:medic", "die:medic"], "separate": true, "text": "Splice grants 3 heal and 3 shield. Target Strike to absorb incoming damage.", "advance": "assigned", "hero": "medic", "target_hero": "combat"},
		{"targets": ["roll_button"], "text": "All three heroes are assigned. They act in numbered order. End the turn.", "advance": "turn_resolved", "round": 1},
		{"targets": ["roll_button"], "text": "Roll to see your next choices.", "advance": "roll_pressed"},
		{"hide_coach": true, "advance": "rolled"},
		{"targets": ["protocol_value", "nudge"], "separate": true, "text": "Each completed turn earns 1 Protocol, shown below. Spend 1 to Nudge a die up by 3. Try it now.", "armed_text": "Select Strike's die: 8 becomes 11, changing 6 damage to 10.", "advance": "nudged", "hero": "combat"},
		{"targets": ["card:combat", "die:combat"], "separate": true, "text": "Select Strike's new 10-damage attack, then target SCRAP.", "advance": "assigned", "hero": "combat"},
		{"targets": ["card:engineer", "die:engineer"], "separate": true, "text": "This roll gives Engineer 9 shield. Protect Strike.", "advance": "assigned", "hero": "engineer", "target_hero": "combat"},
		{"targets": ["card:medic", "die:medic"], "separate": true, "text": "Select Splice, then heal Strike.", "advance": "assigned", "hero": "medic", "target_hero": "combat"},
		{"targets": ["roll_button"], "text": "Your attack, shield and heal are ready. End the turn.", "advance": "turn_resolved", "round": 2},
		{"fullscreen": true, "title": "YOUR TURN", "text": "Finish SCRAP. Choose your targets and order; spend Protocol if useful. Hold portraits for help."},
		{"fullscreen": true, "hide_coach": true, "free": true, "advance": "won"},
		{"fullscreen": true, "title": "BATTLE COMPLETE", "text": "You won! After each battle, choose an item as your reward.", "advance": "tap_finish"},
	]

static func practice() -> Array:
	return [
		{"fullscreen": true, "title": "NEXT BATTLE", "text": "Two enemies this time. Pulse replaces Engineer so we can learn some new abilities. Your chosen item is in your inventory."},
		{"targets": ["roll_button"], "text": "Roll to see your options.", "advance": "roll_pressed"},
		{"hide_coach": true, "advance": "rolled"},
		{"targets": ["card:combat", "die:combat"], "separate": true, "title": "MARK", "glyph": "mark", "text": "Mark makes the next hit deal 50% more damage. Select Strike, then choose a SCRAP.", "advance": "assigned", "hero": "combat"},
		{"targets": ["ability:pulse", "die:pulse"], "separate": true, "title": "BURN", "glyph": "burn", "text": "Pulse deals 6 damage now and 2 Burn damage next turn. Target the same SCRAP: Mark increases this turn's hit by 50%.", "advance": "assigned", "hero": "pulse"},
		{"fullscreen": true, "title": "PROTECT YOUR SQUAD", "text": "Choose who needs Splice's heal and shield, then end the turn. Burn deals its damage at the end of the next turn."},
		{"hide_coach": true, "advance": "turn_resolved", "free": true},
		{"targets": ["item"], "title": "USE AN ITEM", "text": "After rolling, open your inventory to use your reward. Using an item costs 1 Protocol and consumes it."},
		{"fullscreen": true, "title": "YOUR PLAN", "text": "Choose your targets and attack order. Spend Protocol if useful. Watch Burn deal damage at the end of this turn."},
		{"fullscreen": true, "hide_coach": true, "free": true, "advance": "won"},
		{"fullscreen": true, "title": "MORE TO DISCOVER", "text": "You learned Mark and Burn. More effects will be explained when you first encounter them. Open Help to review them anytime."},
		{"fullscreen": true, "title": "TRAINING COMPLETE", "text": "Thanks for training. Now select your squad and begin your run!", "advance": "tap_finish"},
	]
