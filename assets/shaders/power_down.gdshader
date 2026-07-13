shader_type canvas_item;

// POWER DOWN (docs/TRANSITIONS_SCOPE.md) — CRT power-off, DEFEAT ONLY (ruling
// Kev 2026-07-12: it exclusively means you died; quit/victory use the dissolve).
// 0.8s ramp — the one moment that should linger:
//   phase 1 (0.00-0.55): frame collapses vertically to a bright horizontal line
//   phase 2 (0.55-0.85): the line collapses horizontally to a dot
//   phase 3 (0.85-1.00): dot afterglow fades out, revealing the run-end screen
//
// `backdrop` is set by TransitionManager from PixelUI.DT_FIELD_BG (never
// hardcode hex) — the void the frame collapses over.

uniform float ramp : hint_range(0.0, 1.0) = 0.0;
uniform vec4 backdrop : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	float p1 = clamp(ramp / 0.55, 0.0, 1.0);
	float p2 = clamp((ramp - 0.55) / 0.30, 0.0, 1.0);
	float p3 = clamp((ramp - 0.85) / 0.15, 0.0, 1.0);
	// Squared easing: slow start, fast collapse — a CRT giving up.
	float vy = mix(1.0, 0.0015, p1 * p1);
	float hx = mix(1.0, 0.003, p2 * p2);
	vec2 suv = (UV - 0.5) / vec2(hx, vy) + 0.5;
	vec3 rgb = backdrop.rgb;
	if (suv.x >= 0.0 && suv.x <= 1.0 && suv.y >= 0.0 && suv.y <= 1.0) {
		// Brightness flare as the frame compresses into the line/dot.
		float flare = 1.0 + p1 * 2.5 + p2 * 2.0;
		rgb = texture(TEXTURE, suv).rgb * flare;
	}
	// Afterglow: the whole overlay (dot + backdrop) fades to reveal run-end.
	COLOR = vec4(rgb, 1.0) * (1.0 - p3);
}
