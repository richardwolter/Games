# Wrapper. The real generator is shared by every game repo and lives in
# ..\..\_pipeline\tools\generate_art.ps1 -- edit it there, not here.
#
#   .\tools\comfy.ps1 start
#   .\tools\generate_art.ps1 -Name kid_torso -Preview
#   .\tools\generate_art.ps1
#
# All parameters are forwarded untouched; -Project is filled in with this repo
# so `out` and `ref` in art\assets.json resolve here regardless of the caller's
# current directory.

$shared = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "_pipeline\tools\generate_art.ps1"
if (-not (Test-Path $shared)) { throw "shared generator not found: $shared" }

& $shared -Project (Split-Path $PSScriptRoot -Parent) @args
