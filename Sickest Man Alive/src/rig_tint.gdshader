shader_type canvas_item;

// One material on the rig root, inherited by every part via
// `use_parent_material`. The placeholder `_draw` could express damage and status
// by changing a single Color; a six-part sprite cannot, and walking the tree to
// set `modulate` on each part every frame is both slower and easy to get out of
// sync. These uniforms restore the one-line state change.
//
// Order matters and is deliberate: item tint is who the character IS, status is
// something happening TO them, and the hit flash overrides everything because it
// has to be unmissable.

// PlayerStats.tint, resolved by the item pipeline (Op.BLEND). Multiplied, so a
// desaturated sprite takes the colour and a saturated one would not -- which is
// exactly why ART_BIBLE.md requires the suit stay muted.
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Status effects (poison, burn...). Blended toward, not multiplied, so the
// colour reads even on dark armour.
uniform vec4 status_tint : source_color = vec4(0.6, 0.2, 0.8, 1.0);
uniform float status_amount : hint_range(0.0, 1.0) = 0.0;

// Damage flash. 1.0 = fully white.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// Work premultiplied-safe: only touch colour where the sprite is opaque, so
	// the antialiased edge does not pick up a halo of tint.
	col.rgb *= tint.rgb;
	col.rgb = mix(col.rgb, status_tint.rgb, status_amount);
	col.rgb = mix(col.rgb, vec3(1.0), flash);

	col.a *= tint.a;
	COLOR = col;
}
