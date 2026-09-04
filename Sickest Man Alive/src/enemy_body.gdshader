shader_type canvas_item;

// Enemy body: damage state, status colour and the hit flash, all on one sprite.
//
// The placeholder circle showed health with an inner core that shrank as it
// died. A sprite has no equivalent, and losing that read would have made every
// enemy look identical until the instant it popped -- so damage is written on
// the body instead: it CRACKS. Fractures spread and widen as it dies, and in the
// last stretch pieces break out of the silhouette altogether.
//
// The cracks are generated rather than painted, which means every enemy sprite
// gets them for free and no crack artwork has to be drawn or kept in sync.

// 0 undamaged, 1 about to die. Not health directly -- see Enemy._damage_ratio,
// which keeps a healthy enemy completely clean.
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 status_tint : source_color = vec4(0.6, 0.2, 0.8, 1.0);
uniform float status_amount : hint_range(0.0, 1.0) = 0.0;

// Emission, for the one creature that has to be visible in spite of its own
// colour. `tint` MULTIPLIES, so a body drawn dark on purpose can only ever get
// darker -- there is no value of it that makes something glow. This adds instead
// of scaling, so the drained blue-grey stays drained and still reads across a
// near-black floor. Zero by default: every other creature is unaffected.
uniform vec4 glow_tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow_amount = 0.0;

// How many fracture cells across the sprite. Higher is finer, more shattered
// glass than broken shell.
uniform float cell_scale = 6.5;
// Where chunks start breaking off, as a fraction of `damage`.
uniform float chip_start : hint_range(0.0, 1.0) = 0.62;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Distance between the nearest and second-nearest cell centres. It goes to zero
// exactly on the boundary between two cells, which is what draws the crack --
// cell EDGES, not cell interiors, so the result is a connected web rather than
// scattered blobs.
float fracture(vec2 uv) {
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 p = o + hash2(cell + o) - f;
			float d = dot(p, p);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// Nothing below happens outside the silhouette: cracking empty space would
	// paint lines across the transparent margin.
	if (col.a > 0.01) {
		float edge = fracture(UV * cell_scale);

		// Cracks start hairline and open up. The floor keeps them from appearing
		// as full-width gashes the moment damage becomes non-zero.
		float width = 0.02 + 0.13 * damage;
		// `raw` is the crack SHAPE, independent of how hurt the enemy is.
		// `crack` is how strongly it is drawn. Keeping them apart matters: the
		// chips below key off the shape, and gating those on the faded value
		// meant the threshold was never reached and nothing ever broke off.
		float raw = 1.0 - smoothstep(0.0, width, edge);
		float crack = raw * damage;

		// Cracks are dark. An earlier version bled sick green light out of them,
		// but that glow came out brighter than the darkened body around it, so
		// the fractures read as pale scratches instead of holes. The green is
		// now a faint edge on the deepest ones only.
		col.rgb = mix(col.rgb, col.rgb * 0.10, crack);
		col.rgb += vec3(0.05, 0.11, 0.02) * smoothstep(0.75, 1.0, crack);

		// Late on, the widest cracks punch through and pieces are simply gone.
		float chip = smoothstep(chip_start, 1.0, damage);
		col.a -= smoothstep(0.45, 0.95, raw) * chip;
	}

	col.rgb *= tint.rgb;
	// Multiplied by alpha so it lights the BODY and not the transparent margin
	// around it -- added flat, the glow would square off the silhouette.
	col.rgb += glow_tint.rgb * glow_amount * col.a;
	col.rgb = mix(col.rgb, status_tint.rgb, status_amount);
	col.rgb = mix(col.rgb, vec3(1.0), flash);
	col.a *= tint.a;
	COLOR = col;
}
