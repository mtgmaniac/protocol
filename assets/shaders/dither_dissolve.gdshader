shader_type canvas_item;

// DITHER DISSOLVE with a COVER phase (docs/TRANSITIONS_SCOPE.md — supersedes the
// 2026-07-12 "dissolve-direct, no cover" ruling). Three beats, never a blend:
//   OUT  (ramp 0 .. OUT_END)      the outgoing snapshot dithers away to the
//                                 opaque backdrop — nothing of the incoming
//                                 scene shows.
//   HOLD (OUT_END .. HOLD_END)    fully covered; the scene swap happens under
//                                 this cover (concealing the load).
//   IN   (HOLD_END .. 1)          the backdrop dithers away (discard) to reveal
//                                 the incoming scene beneath.
// Direct dissolve read as a crossfade because both frames were simultaneously
// visible; the cover beat is what makes it read as a transition. The player
// perceives a genuine empty "in between".
//
// PIXEL LAW (INVARIANTS #14): the threshold is computed on FRAGCOORD *device*
// pixels, 2 device px per dither cell — whole even blocks at every window scale
// (1080-native and the exact-half 540x1200 preview), no shimmer.

uniform float ramp : hint_range(0.0, 1.0) = 0.0;
// The opaque "empty" the frame dithers to and back from (TransitionManager
// passes PixelUI.DT_FIELD_BG — the game's darkest surface, reads as solid black).
uniform vec4 backdrop : source_color = vec4(0.0);

const int BAYER[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
// Ramp fractions for the three beats (with 0.27s total: ~0.10 out / 0.05 hold /
// ~0.12 in). Snappy but with a readable cover.
const float OUT_END = 0.37;
const float HOLD_END = 0.55;

void fragment() {
	ivec2 cell = (ivec2(FRAGCOORD.xy) / 2) % 4;
	float threshold = (float(BAYER[cell.y * 4 + cell.x]) + 0.5) / 16.0;
	if (ramp < OUT_END) {
		// OUT: each cell flips snapshot -> backdrop in dither order.
		float p = ramp / OUT_END;
		COLOR = (p >= threshold) ? vec4(backdrop.rgb, 1.0) : vec4(texture(TEXTURE, UV).rgb, 1.0);
	} else if (ramp < HOLD_END) {
		// HOLD: fully opaque cover — the empty beat.
		COLOR = vec4(backdrop.rgb, 1.0);
	} else {
		// IN: each cell flips backdrop -> transparent, revealing the new scene.
		float p = (ramp - HOLD_END) / (1.0 - HOLD_END);
		if (p >= threshold) {
			discard;
		}
		COLOR = vec4(backdrop.rgb, 1.0);
	}
}
