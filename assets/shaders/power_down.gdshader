shader_type canvas_item;

// POWER DOWN (docs/TRANSITIONS_SCOPE.md) — CRT power-off, DEFEAT ONLY (it
// exclusively means you died; quit/victory use the dissolve). Keeps its own
// shape — collapse to a dot over the backdrop — but the reveal on the other
// side now goes through the DISSOLVE-IN from black, never an alpha crossfade:
//   COLLAPSE (ramp 0 .. COLLAPSE_END): frame collapses vertically to a bright
//     line, then horizontally to a dot, and the dot fades to a full backdrop
//     cover — nothing of the incoming scene shows.
//   IN       (COLLAPSE_END .. 1):      the backdrop dithers away (discard) to
//     reveal the run-end screen, same dither-in as the dissolve.
//
// `backdrop` is TransitionManager's PixelUI.DT_FIELD_BG — the void it collapses
// over and dithers back from.

uniform float ramp : hint_range(0.0, 1.0) = 0.0;
uniform vec4 backdrop : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const int BAYER[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
const float COLLAPSE_END = 0.72;  // ramp fraction: collapse + settle to cover; then dither-in

void fragment() {
	if (ramp < COLLAPSE_END) {
		float cp = ramp / COLLAPSE_END;                      // 0..1 across the collapse
		float p1 = clamp(cp / 0.60, 0.0, 1.0);               // vertical collapse to a line
		float p2 = clamp((cp - 0.60) / 0.30, 0.0, 1.0);      // line collapses to a dot
		float dotfade = clamp((cp - 0.90) / 0.10, 0.0, 1.0); // dot fades to full cover
		// Squared easing: slow start, fast collapse — a CRT giving up.
		float vy = mix(1.0, 0.0015, p1 * p1);
		float hx = mix(1.0, 0.003, p2 * p2);
		vec2 suv = (UV - 0.5) / vec2(hx, vy) + 0.5;
		vec3 rgb = backdrop.rgb;
		if (suv.x >= 0.0 && suv.x <= 1.0 && suv.y >= 0.0 && suv.y <= 1.0) {
			float flare = 1.0 + p1 * 2.5 + p2 * 2.0;  // brightness flare as it compresses
			rgb = texture(TEXTURE, suv).rgb * flare;
		}
		COLOR = vec4(mix(rgb, backdrop.rgb, dotfade), 1.0);
	} else {
		// IN: dither away the cover to reveal run-end (never an alpha crossfade).
		ivec2 cell = (ivec2(FRAGCOORD.xy) / 2) % 4;
		float threshold = (float(BAYER[cell.y * 4 + cell.x]) + 0.5) / 16.0;
		float p = (ramp - COLLAPSE_END) / (1.0 - COLLAPSE_END);
		if (p >= threshold) {
			discard;
		}
		COLOR = vec4(backdrop.rgb, 1.0);
	}
}
