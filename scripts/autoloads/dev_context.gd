# Profile isolation (Kev ruling 2026-07-12): test and capture rigs must NEVER
# resolve to the real player profile — structurally impossible, not merely
# discouraged. Backup/restore is a discipline fix, and discipline fails: the
# 2026-07-12 incident had a windowed capture rig wipe and repopulate the real
# primer ledger (user://save.json), which then presented as a game bug (icons
# "never firing"). The same hole could eat run stats, unlocks, or the
# tutorial-completed flag.
#
# is_isolated() is true in every non-player context:
#   - headless (all smoke tests, audits, CI)
#   - any `-s / --script` launch (windowed capture/diagnostic rigs — these have
#     a real renderer, so the old headless-only guard never covered them)
# Persistence owners (SaveManager save.json, AudioManager settings.cfg) consult
# this at _ready and swap to dev_* scratch files. The verify gate's "profile
# isolation" check hashes the real files across the whole suite and fails on
# any change — enforcement on top of impossibility.
class_name DevContext
extends RefCounted


static func is_isolated() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var args: PackedStringArray = OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == "-s" or args[i] == "--script":
			return true
	return false
