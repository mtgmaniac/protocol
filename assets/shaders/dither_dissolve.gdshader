shader_type canvas_item;

// DITHER DISSOLVE (docs/TRANSITIONS_SCOPE.md) — the outgoing snapshot dissolves
// in ordered-dither order, revealing the new scene DIRECTLY beneath (dissolve-
// direct ruling, Kev 2026-07-12 — no through-black phase). Direction-05
// "Dithered Terminal" signature as a transition.
//
// PIXEL LAW (INVARIANTS #14): the threshold is computed on FRAGCOORD *device*
// pixels, 2 device px per dither cell — whole even blocks at every window
// scale (1080-native and the exact-half 540x1200 preview), no shimmer.

uniform float ramp : hint_range(0.0, 1.0) = 0.0;
uniform vec4 backdrop : source_color = vec4(0.0);  // unused here; shared uniform contract

const int BAYER[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};

void fragment() {
	ivec2 cell = (ivec2(FRAGCOORD.xy) / 2) % 4;
	float threshold = (float(BAYER[cell.y * 4 + cell.x]) + 0.5) / 16.0;
	if (ramp >= threshold) {
		discard;  // dissolved pixels reveal the incoming scene
	}
	COLOR = texture(TEXTURE, UV);
}
