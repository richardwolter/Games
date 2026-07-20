"""One-off regeneration of the project's reference PDFs from current doc state.
Run: uv run --with reportlab python scripts/tools/gen_docs_pdfs.py
Not part of the game build — a docs tool, safe to delete after use.
"""
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, ListFlowable, ListItem,
    HRFlowable, Table, TableStyle,
)

styles = getSampleStyleSheet()
title_style = ParagraphStyle("TitleX", parent=styles["Title"], alignment=0, fontSize=22, spaceAfter=4)
h1 = ParagraphStyle("H1", parent=styles["Heading1"], fontSize=16, spaceBefore=14, spaceAfter=8)
h2 = ParagraphStyle("H2", parent=styles["Heading2"], fontSize=12.5, spaceBefore=10, spaceAfter=6)
body = ParagraphStyle("BodyX", parent=styles["Normal"], fontSize=10, leading=14, spaceAfter=8)
meta = ParagraphStyle("Meta", parent=styles["Normal"], fontSize=10, leading=14, spaceAfter=4)
bullet = ParagraphStyle("Bullet", parent=styles["Normal"], fontSize=10, leading=14)


def hr():
    return HRFlowable(width="100%", thickness=0.6, color=colors.HexColor("#cccccc"), spaceBefore=6, spaceAfter=6)


def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(i, bullet), leftIndent=6) for i in items],
        bulletType="bullet", start="•", leftIndent=18, spaceBefore=2, spaceAfter=8,
    )


def build(path, title, version, status, blocks):
    doc = SimpleDocTemplate(path, pagesize=letter,
                             topMargin=0.9 * inch, bottomMargin=0.9 * inch,
                             leftMargin=0.9 * inch, rightMargin=0.9 * inch)
    story = [Paragraph("Semi-Secret Wars", title_style), Paragraph(title, ParagraphStyle("Sub", parent=styles["Heading1"], fontSize=16, spaceAfter=6))]
    story.append(Paragraph(f"<b>Version:</b> {version}", meta))
    story.append(Paragraph(f"<b>Status:</b> {status}", meta))
    story.append(hr())
    for block in blocks:
        kind = block[0]
        if kind == "h1":
            story.append(Paragraph(block[1], h1))
        elif kind == "h2":
            story.append(Paragraph(block[1], h2))
        elif kind == "p":
            story.append(Paragraph(block[1], body))
        elif kind == "b":
            story.append(bullets(block[1]))
        elif kind == "hr":
            story.append(hr())
        elif kind == "table":
            headers, rows = block[1], block[2]
            data = [headers] + rows
            t = Table(data, hAlign="LEFT")
            t.setStyle(TableStyle([
                ("FONTSIZE", (0, 0), (-1, -1), 9),
                ("LINEBELOW", (0, 0), (-1, 0), 0.75, colors.black),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
            ]))
            story.append(t)
            story.append(Spacer(1, 8))
    doc.build(story)
    print("wrote", path)


# ---------------------------------------------------------------------------
# 1. GDD
# ---------------------------------------------------------------------------
gdd = [
    ("h1", "1. Game Overview"),
    ("h2", "Title"), ("p", "Semi-Secret Wars"),
    ("h2", "Genre"), ("p", "Roguelite Auto-Battler — run-based, chained fixed levels, permadeath within a run."),
    ("h2", "Engine"), ("p", "Godot 4.7-stable, GL Compatibility"),
    ("h2", "Target Platform"), ("p", "PC, 1920×1080 fullscreen"),
    ("h2", "Project Status"), ("p", "Vertical slice — 3 levels, 4 heroes, full run loop playable end-to-end and Designer-verified."),
    ("hr",),
    ("h1", "2. High Concept"),
    ("p", "Semi-Secret Wars is a minimalist roguelite auto-battler presented as the pages of a child's comic notebook. "
          "A <b>run</b>, not a single battle, is the unit of play: the player drafts a party once, then chains through a "
          "series of fixed, authored levels — carrying HP, in-run levels, and boons forward — until the party wipes. "
          "A loss sends the player back to Level 1. What persists between runs is <b>knowledge</b> (a permanent, "
          "fog-revealed map of each level) and <b>gold</b> (permanent ability upgrades)."),
    ("hr",),
    ("h1", "3. Design Pillars"),
    ("b", [
        "The run, not the battle, is the unit of play",
        "Knowledge as progression — mastering a fixed, fog-revealed map",
        "One meaningful in-battle lever (focus ping), otherwise fully automated combat",
        "Permanent, low-friction meta-growth (gold-bought ability mods)",
        "Simple, charming notebook presentation",
        "Real attrition — the dead stay dead within a run",
    ]),
    ("hr",),
    ("h1", "4. Target Experience"),
    ("p", "The player should feel that:"),
    ("b", [
        "Every run leans on what was learned and unlocked in the last one.",
        "A wipe is a fresh attempt, not a reset to zero — the map and the gold-bought kit persist.",
        "Strategy happens at prep (party draft, mod purchases); combat itself is decisive and automatic.",
        "The one command they have — focus ping — matters when they use it.",
        "Losing a hero mid-run has real weight; there is no revive.",
    ]),
    ("hr",),
    ("h1", "5. Gameplay Loop"),
    ("h2", "Prep (once per run)"),
    ("b", ["Draft a 3-of-4 party.", "Spend gold on permanent ability mods."]),
    ("h2", "Per level"),
    ("b", [
        "Deploy the party on a fixed field. Fog persists — a level explored on an earlier run stays revealed forever.",
        "Heroes fight automatically: escalating swarm from authored gates, hazards, objective markers for XP; heroes level up in-run via 1-of-3 boon picks.",
        "The player has one command verb — a limited-charge <b>focus ping</b> — to bias where the party commits.",
        "The villain sits dormant at a learnable lair until the party closes in, then fights in its own style.",
        "Win (villain down) chains straight into the next level, carrying HP/boons/levels; the dead stay dead. A wipe ends the run, awards gold (scaled by levels cleared), and returns to prep at Level 1.",
    ]),
    ("hr",),
    ("h1", "6. Visual Direction"),
    ("h2", "Art Style"),
    ("b", ["Minimalist, hand-drawn", "Notebook aesthetic, child's comic book", "Simple colors, thick outlines, imperfect shapes"]),
    ("p", "The game takes place inside the pages of a child's notebook. Terrain and obstacles render with a hand-inked, cross-hatched style; heroes and minions use real sprites (Thundaar, Minion) with placeholder art for the rest."),
    ("h2", "Animation Style"),
    ("p", "Inspired by South Park, paper puppets, and children's doodles. Animations use body bobbing, small rotations, simple scaling, and limited keyframes — personality over realism."),
    ("hr",),
    ("h1", "7. Heroes"),
    ("p", "Roster (4, draft 3-of-4 per run): <b>Thundaar</b> (Tank — Stomp AoE/knockback), <b>Artemis</b> (Burst — Clone taunting stand-in), "
          "<b>WARDEN</b> (Control — Ensnare roots a cluster), <b>BEACON</b> (Support — Rally damage + attack-speed buff)."),
    ("p", "Every hero has its full ability kit from run start (abilities are intrinsic, not unlocked). Growth comes from two sources: "
          "in-run boons (reset each run, picked 1-of-3 on level-up) and permanent gold-bought ability mods (owned forever, bought at prep). "
          "The 8 ability mods are currently upside-only — their designed downsides are disabled in code while Level 1 tuning is the focus (2026-07-18)."),
    ("hr",),
    ("h1", "8. Villains"),
    ("p", "One villain per level, each sitting dormant at a fixed lair until a hero closes in or lands a hit:"),
    ("b", [
        "Level 1 — Dark Mage: teleport/resummon, leashed to its lair so a chasing party's progress isn't reset by the old un-catchable flee.",
        "Level 2 — Berserker: charge/recover aggression pattern.",
        "Level 3 — Mech Robot: stationary, periodic slow-zone AoE.",
    ]),
    ("hr",),
    ("h1", "9. Minions"),
    ("p", "Swarms pour from authored, fixed gates per level (escalating throughput/caps). They hunt the nearest hero field-wide, steer to "
          "intercept the hero's route, and exist to delay progression and protect the villain."),
    ("hr",),
    ("h1", "10. Battlefields / Levels"),
    ("p", "Three authored levels (Levels 1–3), each a fixed layout (not randomized): obstacles, lakes, objectives, scenery, the villain lair, "
          "and minion gates, defined in `config/level_layout.gd` resources. Fog of war persists per level to disk — explored ground stays "
          "revealed forever across runs, making the map itself a form of permanent progression."),
    ("hr",),
    ("h1", "11. Objectives & Hero Priorities"),
    ("p", "Before a run, the player assigns each hero a battlefield priority:"),
    ("b", ["Attack Minions — engage nearby enemies, advance when clear", "Capture Objectives — hold until captured (commits once spotted), then advance", "Attack Villain — push toward the villain, fight only what blocks the path", "Support Allies — default for Support-role heroes"]),
    ("hr",),
    ("h1", "12. Combat"),
    ("p", "Fully automated open-field movement with obstacle avoidance. Minions attempt to intercept; heroes pursue their assigned priority "
          "toward objectives/villain. The player's only live input is the <b>focus ping</b> — 3 charges, a dropped marker that heroes converge "
          "on for 5s and that biases target selection toward enemies near it; a charge refunds on objective capture. Locking onto an alerted "
          "villain makes the ping track his live position."),
    ("hr",),
    ("h1", "13. Progression"),
    ("p", "Two currencies, two horizons:"),
    ("b", [
        "XP (in-run only): kills + objective captures feed each hero's in-run level. On level-up, pick 1 of 3 boons (Power/Vitality/Haste/Swiftness/Fortune/Ferocity). Boons reset every run but carry across levels within a run. Levels 0–2 cost half XP so the first picks land fast.",
        "Gold (permanent): awarded at run end, scaled by levels cleared. Spent at prep on permanent per-hero ability mods — bought once, owned forever.",
    ]),
    ("p", "The deepest progression is <b>knowledge</b>: fixed levels plus persistent fog mean the player learns each map — gate positions, the "
          "lair, hazards, objective spots — and every run leans on what they've already mapped and unlocked."),
    ("hr",),
    ("h1", "14. Game Economy"),
    ("p", "Rewards: XP (kills + objective capture) feeds in-run boons; gold (awarded at run end) buys permanent ability mods; map knowledge "
          "(persistent fog) is earned simply by surviving further into a level. See BALANCE.md for exact economy values."),
    ("hr",),
    ("h1", "15. Balance Philosophy"),
    ("p", "The game should reward persistence and map mastery rather than luck. A loss should feel like a fresh, better-armed attempt — not "
          "a reset to zero — because the fog map and the gold-bought kit both persist. Balance values remain configurable and are tracked in "
          "BALANCE.md rather than hardcoded."),
    ("hr",),
    ("h1", "16. Audio"),
    ("p", "Music: TBD. Sound Effects: TBD. Voice Acting: TBD. See AUDIO_BIBLE.md."),
    ("hr",),
    ("h1", "17. Narrative"),
    ("p", "Story: TBD. Setting: a child's notebook. No narrative content implemented yet — the notebook framing is purely visual/tonal so far."),
    ("hr",),
    ("h1", "18. Localization & Accessibility"),
    ("p", "Both TBD — see LOCALIZATION.md. Player-facing text should eventually use localization keys."),
    ("hr",),
    ("h1", "19. Known TBDs"),
    ("b", [
        "Exact combat formulas & damage calculations",
        "Full ability-mod tradeoff rebalance (downsides currently disabled)",
        "Level 2/3 balance pass (still on stale pre-rework numbers)",
        "Value-proposition playtest (does replaying a mapped level feel like mastery?)",
        "Between-level heal/revive (deliberately deferred)",
        "Partner-pairing deploy rule",
    ]),
    ("hr",),
    ("h1", "Revision History"),
    ("table", ["Version", "Date", "Notes"], [
        ["0.1", "2026-07-13", "Initial design document (all TBD)"],
        ["0.2", "2026-07-18", "Full rewrite: run-chain roguelite rework, 4-hero roster, 3 authored levels, ability-mod economy"],
    ]),
]
build("Semi-Secret Wars GDD.pdf", "Game Design Document (GDD)", "0.2", "Living Document", gdd)


# ---------------------------------------------------------------------------
# 2. Documentation Structure
# ---------------------------------------------------------------------------
docs = [
    ("p", "This folder contains all project documentation. Documentation evolves alongside the game and always "
          "reflects the current state of the project. Unknown information is never invented — use <b>TBD</b> until "
          "a decision has been made."),
    ("hr",),
    ("h1", "README.md"),
    ("p", "Project overview: game summary, current status, engine version, repository structure, documentation links. Audience: everyone."),
    ("h1", "Game_Design_Bible.md"),
    ("p", "Defines what the game is: current scope/direction, core loop, heroes, villains, battlefields, priorities, combat, progression, "
          "rewards, art direction, known TBDs. Does not contain technical implementation. Owner: Lead Game Designer (Richard)."),
    ("h1", "CLAUDE.md / AI_Development_Guide.md"),
    ("p", "Defines how the AI developer (Claude) works this project: roles, session workflow, milestone rules, coding standards, "
          "documentation and testing rules, end-of-session report format. Audience: the AI developer, technical lead, programmers."),
    ("h1", "BACKLOG.md"),
    ("p", "Tracks all planned work. Each item: feature, priority, status, dependencies, notes. Changes frequently."),
    ("h1", "CHANGELOG.md"),
    ("p", "Records completed milestones: date, systems added, systems modified, known issues."),
    ("h1", "BALANCE.md"),
    ("p", "Stores gameplay values: hero/enemy stats, XP/gold economy, ability-mod magnitudes, damage formulas, balance-sweep results. "
          "Every gameplay value should eventually live here instead of in source code."),
    ("h1", "LOCALIZATION.md"),
    ("p", "Tracks player-facing text: localization keys, languages, UI/hero/ability names. Mostly TBD — no localization pass yet."),
    ("h1", "DECISIONS.md"),
    ("p", "Records important project decisions: date, decision, reason, alternatives, impact. Explains WHY decisions were made — currently "
          "holds the 7 ratified decisions behind the run-chain rework plus the design-testing playtest fixes."),
    ("h1", "ART_BIBLE.md / AUDIO_BIBLE.md"),
    ("p", "Define the visual and audio language respectively. Both start small and expand as production grows; audio is still mostly TBD."),
    ("h1", "PRODUCTION.md"),
    ("p", "Tracks project production: current milestone, previous milestones, completed-milestone list, demo scope, next candidates, "
          "production notes. The single place to check \"where is the project right now.\""),
    ("hr",),
    ("h1", "Repository Philosophy"),
    ("p", "Every document has a single responsibility. The project should never have one enormous document. Small documents → easy "
          "maintenance → easy AI context → lower token usage → better onboarding → professional organization."),
    ("h1", "Documentation Rules"),
    ("b", [
        "Keep documents concise.",
        "Update only documents affected by a milestone, and only in a batch at session end.",
        "Never duplicate information across documents — update the original source.",
        "Use TBD when a decision has not yet been made.",
        "The Game Design Bible is the source of truth for gameplay.",
        "PRODUCTION.md / CLAUDE.md are the source of truth for current state and development practices.",
    ]),
]
build("Semi-Secret Wars Documentation.pdf", "Documentation Structure", "0.2", "Living Document", docs)


# ---------------------------------------------------------------------------
# 3. AI Development Guide
# ---------------------------------------------------------------------------
adg = [
    ("h1", "1. Purpose"),
    ("p", "This document defines the development workflow for Semi-Secret Wars — how the AI developer (Claude, working as Lead Gameplay "
          "Programmer) collaborates with the Designer using Godot 4.7-stable. The objective is small, testable milestones with high code "
          "quality and a scalable architecture. This defines <b>how</b> the game is developed, not how the game works — see the GDD for that."),
    ("hr",),
    ("h1", "2. Project Goals"),
    ("b", ["Playable builds", "Small milestones", "Modular systems", "Maintainable code", "Low AI token usage", "Easy testing", "Easy future expansion"]),
    ("hr",),
    ("h1", "3. Roles"),
    ("h2", "Designer — Richard"),
    ("p", "Game design, gameplay decisions, feature approval, QA testing, production direction."),
    ("h2", "Claude — Lead Gameplay Programmer"),
    ("p", "Technical implementation, architecture recommendations, Godot best practices, documentation updates. Creative decisions always "
          "belong to the Designer; Claude may recommend, never impose."),
    ("hr",),
    ("h1", "4. Session Workflow"),
    ("b", [
        "Review the current milestone in PRODUCTION.md.",
        "Explain the implementation plan.",
        "Implement only the approved milestone.",
        "Verify the project runs (use godot-ai MCP tools sparingly, to conserve tokens).",
        "Explain how to test the implementation.",
        "Wait for Designer approval before continuing.",
    ]),
    ("hr",),
    ("h1", "5. Milestone Rules"),
    ("p", "Each milestone solves one problem only. Avoid combining unrelated systems. Every milestone should leave the project playable."),
    ("hr",),
    ("h1", "6. Godot Best Practices"),
    ("p", "Use the latest stable Godot version (4.7-stable, GL Compatibility). Prefer typed GDScript, composition over inheritance, signals, "
          "Resources for configurable data, reusable/modular scenes. Avoid hardcoded gameplay values (use BALANCE.md), large monolithic "
          "scripts, duplicate code, tight coupling, and unnecessary singletons."),
    ("hr",),
    ("h1", "7. Shared State Discipline"),
    ("p", "Shared field state — e.g. StageField.villain_pos — is read by multiple systems. When touching it, check all producers/consumers "
          "game-wide, not just the scene at hand. This has been a real source of bugs in this codebase (see PressureSystem fixes in the commit "
          "history) and is treated as a standing rule, not a one-off caution."),
    ("hr",),
    ("h1", "8. Placeholder Policy"),
    ("p", "Until final production assets exist: use Godot primitives, placeholder UI/characters/effects, no dependence on external assets. "
          "All placeholders should be easy to replace. Thundaar and Minion have graduated to real sprites; the rest remain placeholder."),
    ("hr",),
    ("h1", "9. Coding Standards"),
    ("p", "Scripts should have a single responsibility, be modular, reusable, readable, and documented only where the WHY is non-obvious. "
          "Gameplay values should be configurable rather than hardcoded."),
    ("hr",),
    ("h1", "10. Documentation Rules"),
    ("p", "Update docs only at session end, in batches. Never duplicate info across docs — update the source directly. Significant decisions "
          "get logged in DECISIONS.md when made. Only update documents actually affected by the session's work."),
    ("hr",),
    ("h1", "11. Testing Workflow"),
    ("p", "After implementing: verify the project runs, explain what to test, wait for Designer feedback. Do not continue until approved."),
    ("hr",),
    ("h1", "12. Unknown Information"),
    ("p", "Never invent mechanics. If information is missing, mark it TBD and ask the Designer before implementing assumptions. Do not make "
          "changes until reaching high confidence in what needs to be built — ask follow-up questions first."),
    ("hr",),
    ("h1", "13. End-of-Session Report"),
    ("p", "Include: milestone status, files modified, docs updated, complexity & context estimates."),
    ("hr",),
    ("h1", "Revision History"),
    ("table", ["Version", "Date", "Notes"], [
        ["0.1", "2026-07-13", "Initial version — project foundation"],
        ["0.2", "2026-07-18", "Synced to current CLAUDE.md workflow; added shared-state discipline rule"],
    ]),
]
build("Semi-Secret Wars AI Development Guide.pdf", "AI Development Guide (ADG)", "0.2", "Living Document", adg)


# ---------------------------------------------------------------------------
# 4. AI Development Prompt
# ---------------------------------------------------------------------------
prompt = [
    ("p", "You are the Lead Gameplay Programmer for Semi-Secret Wars. Your responsibility is to help develop the game using Godot "
          "4.7-stable, following modern Godot best practices and maintaining clean, modular, scalable, well-documented code."),
    ("p", "You are part of a small indie development team. Your role is technical implementation. Creative decisions belong to the "
          "Game Designer (Richard)."),
    ("hr",),
    ("h1", "Your Responsibilities"),
    ("b", [
        "Implementing gameplay systems.",
        "Maintaining clean architecture.",
        "Following Godot best practices.",
        "Suggesting technical improvements.",
        "Keeping the project modular and performant.",
        "Updating documentation when necessary.",
        "Helping reduce AI development costs.",
    ]),
    ("p", "You are <b>not</b> responsible for changing gameplay design without approval. If you believe a design decision should be "
          "improved, explain your reasoning, recommend an alternative, and wait for approval."),
    ("hr",),
    ("h1", "Source of Truth"),
    ("p", "Use the following documents in this priority order:"),
    ("b", ["PRODUCTION.md (current milestone & state)", "AI_Development_Guide.md / CLAUDE.md (workflow & standards)", "Game_Design_Bible.md (gameplay rules)"]),
    ("p", "If information conflicts between documents, stop and notify the Designer instead of making assumptions. If information is "
          "missing, mark it TBD and ask before implementing. Never invent gameplay mechanics."),
    ("hr",),
    ("h1", "Development Philosophy"),
    ("p", "The project is developed through small, testable milestones. Never implement multiple major systems in a single iteration. "
          "Every implementation should leave the project playable. Always favor simplicity, modularity, readability, maintainability, "
          "and scalability."),
    ("hr",),
    ("h1", "Godot Standards"),
    ("p", "Prefer typed GDScript, composition over inheritance, signals, Resources, modular scenes, data-driven systems. Avoid hardcoded "
          "gameplay values, large scripts, duplicate logic, tight coupling, premature optimization."),
    ("hr",),
    ("h1", "Documentation"),
    ("p", "Whenever a milestone affects documentation, identify which document(s) should be updated — do not rewrite documentation "
          "unnecessarily, update only what changed, and batch updates to session end (see CLAUDE.md)."),
    ("hr",),
    ("h1", "Testing"),
    ("p", "After every milestone, explain what was implemented, how to test it, expected behavior, and known limitations, then wait for "
          "Designer approval. Do not continue automatically."),
    ("hr",),
    ("h1", "Communication Style"),
    ("p", "Keep responses concise and practical. Explain technical decisions only when relevant to the current milestone. Do not make "
          "changes until reaching high confidence in scope — ask follow-up questions until that confidence is reached."),
    ("hr",),
    ("h1", "Current Status"),
    ("p", "The vertical slice is well past its first milestone: a full run-chain roguelite loop (prep → 3 authored levels → gold reward) "
          "is playable end-to-end with a 4-hero roster. Active work is a Level 1 tightening pass on top of the completed rework — see "
          "PRODUCTION.md for the live milestone."),
]
build("Semi-Secret Wars AI Development Prompt.pdf", "Initial AI Development Prompt", "0.2", "Living Document", prompt)

print("done")
