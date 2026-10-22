## The Donation Bank's ledger (2026-10-22, `/grill-me` with Richard): what this Steam account
## gave, and the last total of every player's gifts that Steam handed back.
##
## A player whose lake is clean may give the money left in their purse, **once per Steam
## account, ever**: a New game does not give another. Steam sums every account's gift into one
## aggregated stat (`Achievements.DONATED`), and when that total reaches `GOAL` Richard donates
## 100 US dollars of real money to The Nature Conservancy Brasil. The pledge is fixed and paid
## by him: whoever cheats the counter can only make it come sooner, never cost more.
##
## This holds no Steam calls. `Achievements` owns the one the game uses (kept in
## `user://achievements.cfg`, section `[donation]`, which Steam Cloud syncs with the rest) and
## talks to Steam for it; a harness or a probe gets a bank of its own with no file
## (`Lake.bank`), so a test can never spend the player's one gift.
class_name DonationBank
extends RefCounted

## The ledger moved: a gift, a total read, a request sent or answered.
signal changed

## The goal, in the game's money: about a hundred finished lakes' leftovers (43-56k each in
## the logged runs). A new goal, if Richard pledges again, ships in an update.
const GOAL := 5000000
## The most one account can give, which is also the Steam stat's own max value and max
## change: one cheating account can add no more than this. Over the whole lake's worth, so a
## real purse never meets it.
const MOST := 1000000
const SECTION := "donation"

## This account's gift, 0 while none has been made.
var given: int = 0
## Whether Steam has the gift. A gift made offline waits here until it does.
var sent: bool = false
## Every player's gifts and how many gave, as Steam last said; `seen_at` is when, in unix
## seconds, 0 for never.
var total: int = 0
var donors: int = 0
var seen_at: int = 0
## The total as it stood when this account gave, plus the gift. Steam folds a gift into its
## global total some time after it lands, so until it shows there the bank counts it itself.
var floor_total: int = 0
## A request for the total is out; one has come back since the game started.
var asking: bool = false
var live: bool = false
## Where the ledger is kept. Empty keeps it nowhere.
var file: String = ""


func has_given() -> bool:
	return given > 0


## This account's gift. False, and nothing changed, if it has given already or has nothing.
func give(amount: int) -> bool:
	if given > 0 or amount <= 0:
		return false
	given = mini(amount, MOST)
	sent = false
	floor_total = total + given
	write()
	changed.emit()
	return true


## The total to show: Steam's, or this account's gift on top of the last one it saw, until
## Steam has caught up.
func shown_total() -> int:
	return maxi(total, floor_total)


func shown_donors() -> int:
	return donors + (1 if given > 0 and total < floor_total else 0)


## How far to the goal, 0 to 1.
func share() -> float:
	return clampf(float(shown_total()) / float(GOAL), 0.0, 1.0)


func reached() -> bool:
	return shown_total() >= GOAL


func read() -> void:
	if file.is_empty():
		return
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return
	given = clampi(int(cfg.get_value(SECTION, "given", 0)), 0, MOST)
	sent = bool(cfg.get_value(SECTION, "sent", false))
	total = maxi(0, int(cfg.get_value(SECTION, "total", 0)))
	donors = maxi(0, int(cfg.get_value(SECTION, "donors", 0)))
	seen_at = maxi(0, int(cfg.get_value(SECTION, "seen_at", 0)))
	floor_total = maxi(0, int(cfg.get_value(SECTION, "floor_total", 0)))


## Into the file's own section, the rest of the file left as it was: the achievements share it.
func write() -> void:
	if file.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.load(file)
	cfg.set_value(SECTION, "given", given)
	cfg.set_value(SECTION, "sent", sent)
	cfg.set_value(SECTION, "total", total)
	cfg.set_value(SECTION, "donors", donors)
	cfg.set_value(SECTION, "seen_at", seen_at)
	cfg.set_value(SECTION, "floor_total", floor_total)
	cfg.save(file)


## A sum of the game's money as the bank writes it: the money mark and the figure grouped in
## threes the way the language groups them ("$5,000,000", "$5.000.000"). The HUD's purse
## writes its figure bare; a goal in the millions does not read that way.
static func figure(amount: int) -> String:
	return "$" + grouped(amount)


static func grouped(amount: int) -> String:
	var digits := str(absi(amount))
	var mark := ","
	var locale := TranslationServer.get_locale()
	if locale.begins_with("pt") or locale.begins_with("es") or locale.begins_with("de"):
		mark = "."
	elif locale.begins_with("fr"):
		mark = " "
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = mark + out
		out = digits[i] + out
		count += 1
	return ("-" if amount < 0 else "") + out
