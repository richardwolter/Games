# Moodboard

Briefs handed to the artist. One folder per subject: the references, plus the
visual and technical instructions for that subject alone.

The game's visual language is still being worked out with the artist, so these
briefs are currently the only reference that counts. Once the aesthetic settles,
the shared rules get lifted out into a single style document and each brief goes
back to carrying only what is specific to its own subject.

## Layout

```
moodboard/
  README.md            this file
  _template/           copy this to start a new subject
  01_main_character/
    MOODBOARD.md       the brief
    moodboard.html     the same brief as a self-contained page for the artist
    Description.txt    Richard's original notes, verbatim
    Links.txt          external references
    ref/
      concept/         our own concept art. The anchor.
      suit/            hardware and costume logic. Shape reference, not style.
      avoid/           wrong turns, each with a caption
    deliverables/      what comes back from the artist
```

Sub-folder names under `ref/` are per subject — they should say what the
reference is *for*, because that is the only thing that tells the artist how
much of it to copy.

Numbered prefixes (`01_`, `02_`) keep the subjects in production order, not
alphabetical order.

## Rules for reference images

- **Name the file for what it shows**, not where it came from:
  `goggles-pushed-up.png`, not `image_47.png`.
- **Every image in `avoid/` needs a line in the brief saying why.** An
  uncaptioned bad example reads as a good one.
- **Say what to take and what to ignore** for every reference. A reference with
  no instructions is copied whole, including the parts that are wrong.
- **Never use a photograph as an img2img input.** Photoreal detail fights the
  flat cartoon look, and stock photography must not be reproduced into shipped
  assets. Look at it, then draw the cartoon version.
- Keep source resolution. The artist can downscale; they cannot upscale.

`.gdignore` in this folder stops Godot importing any of it — moodboard images
are documentation, not game assets, and must never end up in a `.tres`.

## Subjects

| # | Subject | Status |
| --- | --- | --- |
| 01 | [Main character](01_main_character/MOODBOARD.md) | draft — no approved art yet |
