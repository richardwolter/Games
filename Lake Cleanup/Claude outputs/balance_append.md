

---

## Correction (2026-09-06, later) — follow-up 3 was never actually saved

Follow-up 3 above claims `net_strength.tres` was changed to `price_base=150, price_mult=6.0`.
The file on disk still held the old follow-up-2 values (`price_base=80, price_mult=2.3`) —
the edit was written to this log but never applied to the resource. Found and fixed during a
design-review pass; file now matches the follow-up 3 numbers. Still unplaytested, per follow-up
3's own decision note above.
