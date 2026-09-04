# Local art generation setup

Art is generated locally through ComfyUI (SDXL + LayerDiffuse). Nothing leaves
the machine and there is no per-image cost.

## Install location

`C:\Users\Administrador\ComfyUI` — deliberately outside the game repos. Only
finished PNGs land in `art/`.

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

**Never install xformers.** It force-downgrades torch to a build without
`sm_120`. ComfyUI's own `requirements.txt` also lists `torch`/`torchvision`/
`torchaudio` — install those separately from the cu128 index and use
`requirements.notorch.txt` for the rest, or pip will replace the working build.
`torchaudio` IS required (ComfyUI imports it at startup); only the *index* matters.

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
