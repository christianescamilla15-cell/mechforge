shader_type canvas_item;
// Destello de un golpe (OBS-052): lleva el dibujo del robot hacia un color
// sin tocar su silueta. `modulate` multiplica y una pieza oscura nunca llega
// a blanco; esto mezcla, como el cambio de paleta de los juegos de lucha.

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}
