"""Builds the angler's shed rest strips by rule: sitting facing the room, sitting with his back
to it, lying in bed and reading at a bookcase (2026-09-29, /grill-me with Richard, picked off
`tools/last_pose_mockup.png`, which `tools/build_pose_mockup.py` draws from the same poses).

Rules first, polish after: every frame is the idle figure cut and re-laid. Writes
`art_source/character_extracted/<pose>_<dir>.png` for `tools/slice_character.gd`. Richard may
paint over the strips; re-running this overwrites them.

    sit_south   2 frames  facing the room: rest, breath in (the chest opens, the head stays)
    sit_north   2 frames  back to the room, down to the seat of his trousers: rest, breath in
    sit_west    2 frames  in profile facing left, back to a backrest on the right (the same
                          picture twice: a breath in profile only moved the arm)
    sit_east    2 frames  sit_west mirrored
    sitdown_*   1 frame   getting down onto the seat and up off it, each direction
                          (the seated poses: `tools/build_seat_poses.py`, 2026-10-22)
    lie_south   2 frames  face up on a pillow at the far end, down to the chin: awake, then
                          the eyes shut, shown once the Zs come (`ShedRoom.SLEEP_AFTER`)
    lie_north   2 frames  the back of the hat, for a pillow behind the near board (the same
                          picture twice: no eyes to shut, but every lie strip is two frames)
    lie_west    2 frames  lie_south turned a quarter, crown to the left (a side view)
    lie_east    2 frames  the same, crown to the right
                          (the blanket over the rest is the bed's own art, `ShedRoom.LIES`)
    read_south  10 frames five books, each read then page turning (`pose.COVERS`)

Every frame of a strip shares one canvas, bottom aligned, so the ink's foot is the anchor and
a breath moves the body and never the boots. A sitting strip comes with `<strip>_anchor.json`:
the pixel of its cell that goes on the seat's spot, which `tools/slice_character.gd` hands on
as each frame's `anchor`.

Run with the psd-extract venv python from the project root:
    python tools/build_rest_frames.py
"""
import json

from PIL import Image

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_pose_mockup as pose  # noqa: E402
import build_seat_poses as seat  # noqa: E402

OUT = "art_source/character_extracted/%s.png"


def strip(frames):
    wide = max(f.width for f in frames)
    tall = max(f.height for f in frames)
    out = Image.new("RGBA", (wide * len(frames), tall), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * wide, tall - f.height))
    return out


def breathing(fig, rows):
    """The seated pose at rest and with a breath in (`pose.chest_breath`), both on the same
    canvas, the anchor moved with the pad."""
    im, (ax, ay) = fig
    if rows is None:
        rest = pose.chest_breath(im, None, None, None)
        return [rest, rest], (ax + 1, ay)
    top, bottom, middle = rows
    return [pose.chest_breath(im, None, None, None), pose.chest_breath(im, top, bottom, middle)], (ax + 1, ay)


def anchored(name, frames, anchor):
    """Write a sitting strip's anchor, moved by the bottom alignment `strip` does."""
    tall = max(f.height for f in frames)
    ax, ay = anchor
    ay += tall - frames[0].height
    with open(OUT.replace(".png", "_anchor.json") % name, "w") as f:
        json.dump([ax, ay], f)


def seated():
    """The seated strips and their anchors."""
    out = {}
    out["sit_south"] = breathing(seat.sit_front(), (21, 29, 16))
    out["sit_north"] = breathing(seat.sit_back(), (19, 28, 14))
    out["sit_west"] = breathing(seat.sit_side(), None)
    east, anchor = seat.mirror(seat.sit_side())
    out["sit_east"] = breathing((east, anchor), None)
    for name, fig in (
        ("sitdown_south", seat.crouch_front()),
        ("sitdown_north", seat.crouch_back()),
        ("sitdown_west", seat.crouch_side()),
        ("sitdown_east", seat.mirror(seat.crouch_side())),
    ):
        out[name] = ([fig[0]], fig[1])
    return out


def main():
    for name, (frames, anchor) in seated().items():
        strip(frames).save(OUT % name)
        anchored(name, frames, anchor)
        print("wrote", name, len(frames))
    strips = {
        "lie_south": [pose.lying(), pose.lying(True)],
        "lie_north": [pose.lying_back(), pose.lying_back()],
        "lie_west": [pose.lying_side(True), pose.lying_side(True, True)],
        "lie_east": [pose.lying_side(False), pose.lying_side(False, True)],
        "read_south": [
            pose.book_reader(page, cover)
            for cover in range(len(pose.COVERS))
            for page in (0, 1)
        ],
    }
    for name, frames in strips.items():
        strip(frames).save(OUT % name)
        print("wrote", name, len(frames))


if __name__ == "__main__":
    main()
