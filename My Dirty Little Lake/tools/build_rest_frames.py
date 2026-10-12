"""Builds the angler's shed rest strips by rule: sitting facing the room, sitting with his back
to it, lying in bed and reading at a bookcase (2026-09-29, /grill-me with Richard, picked off
`tools/last_pose_mockup.png`, which `tools/build_pose_mockup.py` draws from the same poses).

Rules first, polish after: every frame is the idle figure cut and re-laid. Writes
`art_source/character_extracted/<pose>_<dir>.png` for `tools/slice_character.gd`. Richard may
paint over the strips; re-running this overwrites them.

    sit_south   2 frames  facing the room: rest, breath in (the chest opens, the head stays)
    sit_north   2 frames  back to the room: rest, breath in
    lie_south   2 frames  face up on a pillow at the far end, down to the chin: awake, then
                          the eyes shut, shown once the Zs come (`ShedRoom.SLEEP_AFTER`)
    lie_north   2 frames  the back of the hat, for a pillow behind the near board (the same
                          picture twice: no eyes to shut, but every lie strip is two frames)
    lie_west    2 frames  lie_south turned a quarter, crown to the left (a side view)
    lie_east    2 frames  the same, crown to the right
                          (the blanket over the rest is the bed's own art, `ShedRoom.LIES`)
    read_south  10 frames five books, each read then page turning (`pose.COVERS`)

Every frame of a strip shares one canvas, bottom aligned, so the ink's foot is the anchor and
a breath moves the body and never the boots. How far above the foot the hips are is
`ShedRoom.SIT_HIP` and must match what the frames draw.

Run with the psd-extract venv python from the project root:
    python tools/build_rest_frames.py
"""
from PIL import Image

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_pose_mockup as pose  # noqa: E402

OUT = "art_source/character_extracted/%s.png"


def strip(frames):
    wide = max(f.width for f in frames)
    tall = max(f.height for f in frames)
    out = Image.new("RGBA", (wide * len(frames), tall), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * wide, tall - f.height))
    return out


def main():
    strips = {
        "sit_south": [pose.sit_front(0)[0], pose.sit_front(1)[0]],
        "sit_north": [pose.sit_back(0)[0], pose.sit_back(1)[0]],
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
