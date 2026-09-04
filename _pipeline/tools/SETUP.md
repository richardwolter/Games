# Local art generation setup

Art is generated locally through ComfyUI (SDXL + LayerDiffuse). Nothing leaves
the machine and there is no per-image cost.

## Install location

`C:\Users\Administrador\ComfyUI` — deliberately outside the game repos. Only
finished PNGs land in each game's `art/`.

## Layout

The generator is shared by every game repo. It lives here:

```
Games\_pipeline\tools\      comfy.ps1, generate_art.ps1, SETUP.md   <- edit these
Games\<game>\tools\         two-line wrappers that forward to the above
Games\<game>\art\           assets.json manifest + generated PNGs
Games\<game>\art_ref\       reference sprites the manifest's `ref` points at
```

**Edit the shared copy, never a wrapper.** A wrapper exists only so the
documented `.\tools\generate_art.ps1` usage keeps working from a game's root; it
passes `-Project <its own repo>` so `out` and `ref` in that game's manifest
resolve against that game, whatever directory you happened to run from.

The shared script does not use `$PSScriptRoot` to find a project, because
`_pipeline` is not a game. It resolves the project from `-Project`, else from
`-Manifest`'s grandparent, else from the current directory.

## Usage

```powershell
.\tools\comfy.ps1 start          # boot the server (~35s, first load is slowest)
.\tools\generate_art.ps1 -Name tire -Force
.\tools\generate_art.ps1         # everything missing from art/
.\tools\comfy.ps1 stop
```

`generate_art.ps1` skips assets that already exist; `-Force` regenerates.

## Environment notes — the things that will bite on a rebuild

**Python 3.14, not 3.12.** Smart App Control is ON (enforcement) on this machine
and blocks freshly-downloaded unsigned binaries. uv's newly-fetched 3.12 runtime
is blocked at `_ctypes`; the 3.14 runtime already present (from the godot-ai MCP
server) has reputation and passes. If a rebuild fails with
*"Uma política de Controle de Aplicativo bloqueou este arquivo"*, this is why.

**PyTorch must be cu128 or newer.** The RTX 5060 Ti is Blackwell (`sm_120`), and
those kernels did not exist in stable PyTorch before 2.7.0. Currently on
2.11.0+cu128. Verify with:

```powershell
C:\Users\Administrador\ComfyUI\.venv\Scripts\python.exe -c "import torch; print(torch.cuda.get_device_capability(0), 'sm_120' in torch.cuda.get_arch_list())"
```

**App Control blocks the venv's `python.exe`** (seen 2026-08-09, for both the
agent and a normal user shell). Creating a venv on Windows *copies* the
interpreter, and the copy carries no reputation, so the policy refuses it — while
the original it was copied from runs fine.

`comfy.ps1` handles this: it reads `home` from `.venv\pyvenv.cfg`, launches that
interpreter, and puts `.venv\Lib\site-packages` on `PYTHONPATH` by hand. Same
version, same packages, nothing about the policy circumvented.

The failure is nasty because it is silent through `Start-Process`: **exit code 0,
no process, and two zero-length log files**. Run the interpreter directly to see
the real message — *"Uma política de Controle de Aplicativo bloqueou este
arquivo"*.

Consequence for `comfy.ps1 stop`: it now kills a PID recorded at start, in
`ComfyUI\comfy.pid`. It must not go back to matching every `python` process by
path, because the base interpreter is shared with other tools — the godot-ai MCP
server runs on the same one and a path match would take it down too.

**Never install xformers.** It force-downgrades torch to a build without
`sm_120`. ComfyUI's own `requirements.txt` also lists `torch`/`torchvision`/
`torchaudio` — install those separately from the cu128 index and use
`requirements.notorch.txt` for the rest, or pip will replace the working build.
`torchaudio` IS required (ComfyUI imports it at startup); only the *index* matters.

## ControlNet (pose)

`models/controlnet/controlnet-openpose-sdxl.safetensors` —
[xinsir/controlnet-openpose-sdxl-1.0](https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0),
Apache-2.0. Enabled per-asset with `pose` in the manifest.

Skeletons are authored by `make_pose.ps1` rather than extracted from a photo by a
preprocessor node. A preprocessor can only reproduce a camera angle you already
have a photo of, which is no use when the angle you need is the one you do not
have art for.

**Verify the download by size before using it.** A truncated `.safetensors`
fails at load with a shape error rather than anything that says "incomplete" —
`shape '[1280, 1280]' is invalid for input of size 963728`. Confirm the file
matches the size on the model page; do not trust a partially-written file that
happens to have passed some threshold.

## Local patch to ComfyUI-layerdiffuse

`custom_nodes/ComfyUI-layerdiffuse/layered_diffusion.py`, in
`LayeredDiffusionDecodeRGBA.decode`. Upstream calls
`JoinImageWithAlpha().join_image_with_alpha(...)`, but ComfyUI migrated that node
to the V3 schema (`io.ComfyNode` with a classmethod `execute`), so the method no
longer exists and every RGBA decode raises `AttributeError`.

`super().decode()` already returns true alpha; the old path only inverted it to
mask convention so `JoinImageWithAlpha` could invert it straight back. The patch
concatenates directly:

```python
image, alpha = super().decode(samples, images, sd_version, sub_batch_size)
return (torch.cat((image[..., :3], alpha.unsqueeze(-1)), dim=-1),)
```

**This patch is lost if the custom node is updated or reinstalled.** Symptom:
`'JoinImageWithAlpha' object has no attribute 'join_image_with_alpha'`.

## LayerDiffuse settings that actually matter

Use **`SDXL, Conv Injection`**. With `SDXL, Attention Injection` the transparent
decoder produces a washed-out alpha — background around α=128 instead of 0 —
which looks like a broken pipeline but is just the wrong config. Reference
settings from the node's own example workflow: euler / normal / cfg 8 / 20 steps.

Generation dimensions must be multiples of 64 or the decoder asserts.
