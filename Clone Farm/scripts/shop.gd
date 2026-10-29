## The three shops at the Venda stall (docs/scope.md: Terra, Máquina, Ferramentas, 1-2 items
## each), as data. Each shop sells its levels in order; `prices` has one entry per level.
## The farm (main.gd) applies the effect; the menu text is built from these same entries.
class_name Shop
extends RefCounted

const ITEMS := [
	{
		"id": &"terra",
		"label": "Terra",
		"effect": "+3 canteiros",
		"prices": [10, 20],
	},
	{
		"id": &"maquina",
		"label": "Máquina",
		"effect": "+1 característica nos clones novos",
		"prices": [15],
	},
	{
		"id": &"ferramentas",
		"label": "Ferramentas",
		"effect": "+25% Vel. de trabalho (fazendeiro e clones)",
		"prices": [12, 24],
	},
]

## Ferramentas: multiplier on everyone's work speed per level bought.
const TOOL_STEP := 0.25
