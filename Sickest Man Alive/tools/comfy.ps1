# Wrapper. The real script is shared by every game repo and lives in
# ..\..\_pipeline\tools\comfy.ps1 -- edit it there, not here.
#
#   .\tools\comfy.ps1 start | stop | status | log
#
# The server is machine-wide (one ComfyUI install, one port), so there is
# nothing project-specific to pass through.

$shared = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "_pipeline\tools\comfy.ps1"
if (-not (Test-Path $shared)) { throw "shared comfy script not found: $shared" }

& $shared @args
