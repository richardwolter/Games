## Measures the record menu's song titles at the sizes it draws them (headless --script).
extends SceneTree

const Style := preload("res://scripts/style.gd")

func _init() -> void:
	var out := FileAccess.open("res://tools/last_record_titles.log", FileAccess.WRITE)
	for t in ["Movimento Tranquilo", "Tudo Que Eu Fiz", "House by the Lake", "Hello World", "Sanctuary", "This is Nice", "Memory Lane"]:
		out.store_line("%s  body %.0f  small %.0f  tiny %.0f" % [t,
			Style.measure(t, Style.TEXT_BODY).x, Style.measure(t, Style.TEXT_SMALL).x,
			Style.measure(t, Style.TEXT_TINY).x])
	out.close()
	quit()
