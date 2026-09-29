extends "res://scripts/ui/board.gd"
## Are you sure? Two doors, the safe one first and focused. With `countdown` set,
## the question answers itself "no" when the time runs out (the display revert:
## a player looking at a black screen cannot click).

signal answered(yes: bool)

var _left := -1.0
var _words: Label
var _words_fmt := ""
var _no: Button


func _init(title: String, words: String, yes_label: String, no_label: String, countdown: float = -1.0) -> void:
	super(title, 380.0)
	_words_fmt = words
	_words = Ink.label("", Ink.TEXT_BODY, true)
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_words)
	_words.visible = words != ""
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_no = Button.new()
	_no.text = no_label
	_no.pressed.connect(_answer.bind(false))
	row.add_child(_no)
	var yes := Button.new()
	yes.text = yes_label
	yes.pressed.connect(_answer.bind(true))
	row.add_child(yes)
	body.add_child(row)
	_left = countdown
	_show_words()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_no.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if _left < 0.0:
		return
	_left -= delta
	_show_words()
	if _left <= 0.0:
		_answer(false)


func _show_words() -> void:
	_words.text = _words_fmt % ceili(maxf(_left, 0.0)) if _words_fmt.contains("%d") else _words_fmt


func _answer(yes: bool) -> void:
	_left = -1.0
	answered.emit(yes)
	close()
