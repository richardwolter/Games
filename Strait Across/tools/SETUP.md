# Local art generation setup

Moved. The art pipeline is shared by every game repo and is documented once, at:

`..\..\_pipeline\tools\SETUP.md`

`tools\comfy.ps1` and `tools\generate_art.ps1` in this repo are wrappers that
forward to the shared scripts. Usage from this repo's root is unchanged:

```powershell
.\tools\comfy.ps1 start
.\tools\generate_art.ps1 -Name tire -Force
.\tools\comfy.ps1 stop
```

This repo still owns its own `art\assets.json` and `art_ref\` — only the
generator is shared, never the manifest.
