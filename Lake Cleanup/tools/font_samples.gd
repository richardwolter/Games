extends RefCounted
## Sample strings in the eight languages, for judging the faces by eye before any of the
## extraction is built (issue #28, 2026-09-20).
##
## **Not the translation.** These are a handful of the shortest, tightest keys — the shop's
## net board and a run of settings labels — written out so `tools/shot_fonts.gd` can draw the
## real board in each language. The real thing lives in `translations.csv` and goes through
## the artifact page, back-translation and a native speaker. Nothing in `scripts/` reads
## this file and nothing should.
##
## The words here are the ones the width probe will find hardest: a shop row's name gets 87
## design pixels, and "Sound effects" is the widest label on the settings board.

## Every locale the game is going for, in the order the pictures are saved.
const LOCALES: Array[String] = ["en", "pt_BR", "es", "de", "fr", "ja", "zh_CN", "ko"]

## What each is called on its own picture, in its own language — a face that cannot draw its
## own language's name says so at a glance.
const ENDONYM := {
	"en": "English", "pt_BR": "Português (Brasil)", "es": "Español", "de": "Deutsch",
	"fr": "Français", "ja": "日本語", "zh_CN": "简体中文", "ko": "한국어",
}

## The net board: its title, and the five rows that stand on it. The net board is the one
## with no group heading and the longest run of rows, so it is the board a face is judged on.
const BOARD_NET := {
	"en": "Net", "pt_BR": "Rede", "es": "Red", "de": "Netz", "fr": "Filet",
	"ja": "網", "zh_CN": "渔网", "ko": "그물",
}

const ROWS := {
	&"net_strength": {
		"en": "Strength", "pt_BR": "Força", "es": "Fuerza", "de": "Stärke", "fr": "Force",
		"ja": "強さ", "zh_CN": "力量", "ko": "힘",
	},
	&"net_width": {
		"en": "Width", "pt_BR": "Largura", "es": "Ancho", "de": "Breite", "fr": "Largeur",
		"ja": "幅", "zh_CN": "宽度", "ko": "폭",
	},
	&"net_range": {
		"en": "Range", "pt_BR": "Alcance", "es": "Alcance", "de": "Reichweite",
		"fr": "Portée", "ja": "距離", "zh_CN": "距离", "ko": "거리",
	},
	&"reel": {
		"en": "Reel", "pt_BR": "Recolhida", "es": "Recogida", "de": "Einholen",
		"fr": "Moulinet", "ja": "巻取り", "zh_CN": "收线", "ko": "감기",
	},
	&"net_hold": {
		"en": "Catch", "pt_BR": "Captura", "es": "Captura", "de": "Fang", "fr": "Prise",
		"ja": "漁獲", "zh_CN": "渔获", "ko": "어획",
	},
}

## The one word that stands inside a value, and the one that replaces a price.
const TIER_PREFIX := {
	"en": "Tier ", "pt_BR": "Nível ", "es": "Nivel ", "de": "Stufe ", "fr": "Palier ",
	"ja": "階級 ", "zh_CN": "等级 ", "ko": "등급 ",
}
const MAXED := {
	"en": "Max", "pt_BR": "Máx", "es": "Máx", "de": "Max", "fr": "Max",
	"ja": "最大", "zh_CN": "已满", "ko": "최대",
}

## The settings board's labels, drawn as a strip at the real ladder size. The board's own
## `_plan()` is a function and cannot be injected until the extraction lands, so these are
## judged as type rather than in the board — which is the right test for a face anyway.
const SETTINGS := [
	{
		"en": "Settings", "pt_BR": "Ajustes", "es": "Ajustes", "de": "Einstellungen",
		"fr": "Paramètres", "ja": "設定", "zh_CN": "设置", "ko": "설정",
	},
	{
		"en": "Sound effects", "pt_BR": "Efeitos sonoros", "es": "Efectos de sonido",
		"de": "Soundeffekte", "fr": "Effets sonores", "ja": "効果音", "zh_CN": "音效",
		"ko": "효과음",
	},
	{
		"en": "Resolution", "pt_BR": "Resolução", "es": "Resolución", "de": "Auflösung",
		"fr": "Résolution", "ja": "解像度", "zh_CN": "分辨率", "ko": "해상도",
	},
	{
		"en": "Frame cap", "pt_BR": "Limite de quadros", "es": "Límite de fotogramas",
		"de": "Bildratengrenze", "fr": "Limite d'images", "ja": "フレーム上限",
		"zh_CN": "帧率上限", "ko": "프레임 제한",
	},
	{
		"en": "Save and go to menu", "pt_BR": "Salvar e ir ao menu",
		"es": "Guardar e ir al menú", "de": "Speichern und zum Menü",
		"fr": "Sauvegarder et quitter", "ja": "保存してメニューへ",
		"zh_CN": "保存并返回菜单", "ko": "저장하고 메뉴로",
	},
]

## One sentence of running prose, for judging a face at length rather than a word at a time:
## the letter's greeting, which is the longest line the game draws.
const SENTENCE := {
	"en": "Congratulations, you are the new owner of My Dirty Little Lake.",
	"pt_BR": "Parabéns, você é o novo dono do My Dirty Little Lake.",
	"es": "Enhorabuena, eres el nuevo dueño de My Dirty Little Lake.",
	"de": "Herzlichen Glückwunsch, Ihnen gehört jetzt My Dirty Little Lake.",
	"fr": "Félicitations, vous êtes le nouveau propriétaire de My Dirty Little Lake.",
	"ja": "おめでとうございます。あなたが My Dirty Little Lake の新しい持ち主です。",
	"zh_CN": "恭喜，你现在是 My Dirty Little Lake 的新主人。",
	"ko": "축하합니다. 이제 My Dirty Little Lake의 새 주인입니다.",
}


## The net board's five rows as `ShopSkin.rows` wants them, in a locale. Levels, figures and
## prices are a plausible mid-run state — what matters is the words around them.
static func shop_rows(locale: String) -> Array:
	var made: Array = []
	# level, figure now, figure next, and which of the shop's two value grammars the row
	# uses: a share of its own level 0 closed with `%`, or a bare count. Only the two tier
	# tracks take the `Tier` prefix, and `net_hold` — Catch — is neither: it is a plain
	# count, and standing it here maxed is what puts one `Max` tag on the board.
	var levels := {
		&"net_strength": [2, "2", "3", &"tier"], &"net_width": [7, "100", "135", &"pct"],
		&"net_range": [4, "100", "127", &"pct"], &"reel": [11, "285", "309", &"pct"],
		&"net_hold": [5, "9", "10", &"count"],
	}
	var costs := {
		&"net_strength": "$8 750", &"net_width": "$1 663", &"net_range": "$486",
		&"reel": "$3 070", &"net_hold": "",
	}
	for key: StringName in ROWS:
		var at: Array = levels[key]
		var grammar: StringName = at[3]
		var prefix := String(TIER_PREFIX[locale]) if grammar == &"tier" else ""
		var suffix := "%" if grammar == &"pct" else ""
		# `net_hold` stands in for a maxed track: one figure wearing both marks, and the word
		# that replaces a price. Every board needs one to be judged honestly.
		var maxed: bool = key == &"net_hold"
		var said := (
			prefix + String(at[2]) + suffix if maxed
			else "%s%s %s %s%s" % [prefix, at[1], "→", at[2], suffix]
		)
		made.append({
			"key": key,
			"board": &"net",
			"name": String(ROWS[key][locale]),
			"level": str(at[0]),
			"value": said,
			"blurb": "",
			"cost": String(MAXED[locale]) if maxed else String(costs[key]),
			"afford": key in [&"net_range", &"net_width"],
		})
	return made
