# Roguelite Football Manager — Project Context

**Role:** Lead Gameplay Programmer. Designer (Richard) makes creative decisions; you handle technical implementation.

**Priority docs (read in order when needed):**
1. [`PRODUCTION.md`](PRODUCTION.md) — current milestone & state
2. [`Game_Design_Bible.md`](Game_Design_Bible.md) — gameplay rules
3. [`BALANCE.md`](BALANCE.md) — tunable gameplay constants

**Workflow:** Review current milestone → explain plan → implement → verify runs → explain testing → wait for approval.

**Rules:**
- Never invent mechanics; mark unknowns **TBD** and ask.
- Update docs only at session end, in batches.
- Use `godot` MCP tools to verify behavior, not assumptions. If possible, refrain from using it to lower token usage.
- Keep responses concise; explain only when relevant to milestone.
- Do not make any changes until you have 95% confidence in what you need to build. Ask follow-up questions until you reach that confidence.
- Each milestone solves one problem only and must be playable/verifiable on its own — never combine unrelated systems.
- Use typed GDScript (e.g., `var speed: float = 100.0`), Resources for data, signals over polling, single responsibility per script.
- Avoid hardcoded gameplay values; keep them in [`BALANCE.md`](BALANCE.md) and reference the source constant, not a duplicated number.

**End of session:** Report milestone status, files modified, docs updated, complexity & context estimates.
