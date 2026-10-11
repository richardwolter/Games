"""Builds the house-stages mockup out of the designer modules.

    PYTHONPATH=<psd-extract site-packages> python art_source/house_inside/make.py [stills|gifs|all]

Outputs, all in art_source/house_inside/out/:
  stage{1,2,3}.png            the room at each stage, screen resolution, cropped to the room
  stage1_rain.png             stage 1 in a shower
  sheet.png                   the three side by side (half size), labelled
  close_<name>.png            3x close-ups the modules ask for (CLOSEUPS)
  stage{1,2,3}.gif / .mp4     6 s of the room alive (12 fps)
  stage1_rain.gif / .mp4      stage 1 in a shower
  up_1to2.gif, up_2to3.gif    the stage-up play-in, as seen on the next visit, composed on
                              stage frm's capture: the furniture the player already owns
"""
from __future__ import annotations

import importlib
import subprocess
import sys
import traceback

from PIL import Image, ImageDraw

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent))
import base  # noqa: E402

MODULES = ["floor", "damp", "veg", "life"]   # drawn in this order into under/over
FPS = 12
SECONDS = 6.0


def _mods():
    out = []
    for name in MODULES:
        try:
            out.append(importlib.import_module(name))
        except ModuleNotFoundError as err:
            if err.name != name:
                raise
            print(f"(no {name}.py yet)")
    return out


def frame(stage, t, rain=0.0, up=None):
    ctx = base.Ctx(stage, rain)
    ctx.t = t  # the clip clock, for stage_up too
    under, over = base.blank(), base.blank()
    for m in _mods():
        try:
            if up is not None and hasattr(m, "stage_up"):
                m.stage_up(up[0], up[1], ctx, under, over)
            else:
                m.draw(stage, t, ctx, under, over)
        except Exception:
            print(f"--- {m.__name__} failed at stage {stage} t {t}")
            traceback.print_exc()
    return base.room_crop(base.compose(stage, under, over))


def stills():
    base.OUT.mkdir(parents=True, exist_ok=True)
    pics = []
    for stage in (1, 2, 3):
        im = frame(stage, 0.0)
        im.save(base.OUT / f"stage{stage}.png")
        pics.append(im)
    frame(1, 0.0, rain=1.0).save(base.OUT / "stage1_rain.png")
    w, hh = pics[0].width // 2, pics[0].height // 2
    sheet = Image.new("RGB", (w * 3 + 40, hh + 40), (20, 16, 14))
    d = ImageDraw.Draw(sheet)
    for i, im in enumerate(pics):
        sheet.paste(im.resize((w, hh), Image.LANCZOS), (10 + i * (w + 10), 30))
        d.text((10 + i * (w + 10), 8), ["1  abandoned", "2  semi-fixed", "3  fixed"][i], fill=(240, 230, 210))
    sheet.save(base.OUT / "sheet.png")
    rec = __import__("json").loads((base.CAP / "layers.json").read_text(encoding="utf-8"))
    pad = 20 * base.S
    ox, oy = rec["shed"][0] - pad, rec["shed"][1] - pad
    for m in _mods():
        for name, stage, (x, y, w2, h2) in getattr(m, "CLOSEUPS", []):
            src = pics[stage - 1]
            box = (int(x * base.S - ox), int(y * base.S - oy),
                   int((x + w2) * base.S - ox), int((y + h2) * base.S - oy))
            c = src.crop(box)
            c.resize((c.width * 3, c.height * 3), Image.NEAREST).save(base.OUT / f"close_{name}.png")


def _clip(name, frames):
    frames[0].save(base.OUT / f"{name}.gif", save_all=True, append_images=frames[1:],
                   duration=int(1000 / FPS), loop=0, optimize=False)
    tmp = base.OUT / f"_{name}"
    tmp.mkdir(exist_ok=True)
    for i, f in enumerate(frames):
        f.save(tmp / f"f_{i:04d}.png")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i",
                    str(tmp / "f_%04d.png"), "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16",
                    str(base.OUT / f"{name}.mp4")], check=False)


def gifs():
    base.OUT.mkdir(parents=True, exist_ok=True)
    n = int(SECONDS * FPS)
    for stage in (1, 2, 3):
        _clip(f"stage{stage}", [frame(stage, i / FPS) for i in range(n)])
    _clip("stage1_rain", [frame(1, i / FPS, rain=1.0) for i in range(n)])
    for frm in (1, 2):
        k = int(2.5 * FPS)
        _clip(f"up_{frm}to{frm + 1}", [frame(frm, i / FPS, up=(frm, min(1.0, i / (2.0 * FPS))))
                                      for i in range(k)])


def preview(who, t=0.0, rain=0.0):
    """One designer's look at the room so far, without touching the shared outputs:
    out/preview_<who>_stage{n}.png (and _rain for stage 1 when rain > 0)."""
    base.OUT.mkdir(parents=True, exist_ok=True)
    for stage in (1, 2, 3):
        frame(stage, t).save(base.OUT / f"preview_{who}_stage{stage}.png")
    if rain > 0:
        frame(1, t, rain=rain).save(base.OUT / f"preview_{who}_stage1_rain.png")


def preview_clip(who, stage, seconds=3.0, rain=0.0):
    """A short strip of frames for one designer: out/preview_<who>_s<stage>_f<i>.png."""
    base.OUT.mkdir(parents=True, exist_ok=True)
    for i in range(int(seconds * FPS)):
        frame(stage, i / FPS, rain=rain).save(base.OUT / f"preview_{who}_s{stage}_f{i:03d}.png")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "stills"
    if what == "preview":
        # make.py preview <who> [t] [rain]
        preview(sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.0,
                float(sys.argv[4]) if len(sys.argv) > 4 else 0.0)
        sys.exit(0)
    if what == "upclip":
        # make.py upclip <who> <from_stage>: the stage-up play-in as frames,
        # out/preview_<who>_up<frm>_f<i>.png (2.5 s at 12 fps; p runs 0..1 over 2 s)
        base.OUT.mkdir(parents=True, exist_ok=True)
        frm = int(sys.argv[3])
        for i in range(int(2.5 * FPS)):
            frame(frm, i / FPS, up=(frm, min(1.0, i / (2.0 * FPS)))).save(
                base.OUT / f"preview_{sys.argv[2]}_up{frm}_f{i:03d}.png")
        sys.exit(0)
    if what == "clip":
        # make.py clip <who> <stage> [seconds] [rain]
        preview_clip(sys.argv[2], int(sys.argv[3]), float(sys.argv[4]) if len(sys.argv) > 4 else 3.0,
                     float(sys.argv[5]) if len(sys.argv) > 5 else 0.0)
        sys.exit(0)
    if what in ("stills", "all"):
        stills()
    if what in ("gifs", "all"):
        gifs()
