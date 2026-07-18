# Semi-Secret Wars — Development Workflow

## Roles

- **Designer (Richard):** Game design, creative decisions, feature approval, QA
- **Claude (Fable):** Technical implementation, architecture, Godot best practices

Creative decisions always belong to the Designer.

## Session Workflow

For each session:

1. Review current milestone in [PRODUCTION.md](PRODUCTION.md)
2. Explain implementation plan
3. Implement only that milestone
4. Verify project runs
5. Explain testing steps
6. Wait for Designer approval before continuing

## Milestone Rules

- Each milestone solves one problem only (examples: add hero movement, add minion AI, add combat)
- Result must be playable
- Never combine unrelated systems

## Coding Standards

- Use typed GDScript (e.g., `var speed: float = 100.0`)
- Prefer composition over inheritance
- Use signals, Resources, and modular scenes
- Avoid hardcoded values (use [BALANCE.md](BALANCE.md) for gameplay constants)
- Single responsibility per script

## Documentation

- Update docs **only at session end, in batches**
- Never duplicate info across docs — update the source directly
- Significant decisions logged in [DECISIONS.md](DECISIONS.md) when made

## Testing

After implementing:

1. Verify project compiles and runs
2. Explain what to test
3. Wait for Designer feedback
4. Do not continue until approved

## End-of-Session Report

Include:
- Milestone completed
- Files modified/created
- Docs updated
- Complexity & context estimates
- Suggestions to reduce future token usage
