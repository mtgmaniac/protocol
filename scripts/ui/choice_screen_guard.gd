# ChoiceScreenGuard — the zero-options soft-lock guard (PERMANENT FIXTURE,
# documented in docs/TRUTH.md §Run structure). Any between-battle choice screen
# (reward, relic cache, intercept, route fork, evolution/directive) that builds
# ZERO interactive options must not strand the player: this asserts loudly in
# debug (push_error) and, in every build, auto-resolves a logged default so a
# playtest build can never dead-end a stranger.
#
# Usage (after the screen builds its option controls):
#   if not ChoiceScreenGuardScript.ensure_options("reward", count, _auto_resolve_empty):
#       return
# The guard existing is NOT permission to ship empty offers — a [CHOICE_GUARD]
# line in a log is a bug report; fix the offer, never widen the guard.
class_name ChoiceScreenGuard
extends RefCounted


static func ensure_options(screen_name: String, option_count: int, resolve_default: Callable) -> bool:
	if option_count > 0:
		return true
	push_error("[CHOICE_GUARD] %s screen built ZERO options - auto-resolving the default. This is a bug in the offer roll, not normal flow." % screen_name)
	# Telemetry stub: greppable in playtest logs / headless output.
	print("[CHOICE_GUARD][telemetry-stub] screen=%s options=0 auto_resolved=default" % screen_name)
	if resolve_default.is_valid():
		resolve_default.call_deferred()
	return false
