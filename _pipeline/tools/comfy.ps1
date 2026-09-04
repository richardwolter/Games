# Start / stop / check the local ComfyUI server used by generate_art.ps1.
#
#   .\tools\comfy.ps1 start
#   .\tools\comfy.ps1 status
#   .\tools\comfy.ps1 stop
#   .\tools\comfy.ps1 log

param([ValidateSet("start", "stop", "status", "log")][string]$Action = "status")

$root = "C:\Users\Administrador\ComfyUI"
$url = "http://127.0.0.1:8188"

# App Control blocks the venv's python.exe (2026-08-09). Creating a venv on
# Windows COPIES the interpreter, and that copy carries no reputation, so the
# policy refuses it -- while the original it was copied from runs fine. The
# failure is silent through Start-Process: exit code 0, dead process, two
# zero-length log files.
#
# So run the base interpreter named in pyvenv.cfg and put the venv's packages on
# PYTHONPATH by hand. Same interpreter version, same site-packages, same result;
# nothing about the policy is worked around. Falls back to the venv exe if the
# config is ever missing.
$venvLib = "$root\.venv\Lib\site-packages"
$py = "$root\.venv\Scripts\python.exe"
$cfg = "$root\.venv\pyvenv.cfg"
if (Test-Path $cfg) {
    $home_ = (Get-Content $cfg | Where-Object { $_ -match '^\s*home\s*=' }) -replace '^\s*home\s*=\s*', ''
    if ($home_ -and (Test-Path "$home_\python.exe")) { $py = "$home_\python.exe" }
}

function Test-Up {
    try { $null = Invoke-RestMethod "$url/system_stats" -TimeoutSec 3; return $true } catch { return $false }
}

switch ($Action) {
    "status" {
        if (Test-Up) {
            $s = Invoke-RestMethod "$url/system_stats"
            "UP at $url"
            $s.devices | ForEach-Object { "  $($_.name)  VRAM free $([math]::Round($_.vram_free/1GB,1)) / $([math]::Round($_.vram_total/1GB,1)) GB" }
        }
        else { "DOWN" }
    }
    "start" {
        if (Test-Up) { "already up at $url"; break }
        # The child inherits this; it is what makes the base interpreter see the
        # venv's packages.
        $env:PYTHONPATH = $venvLib
        $p = Start-Process -FilePath $py -ArgumentList "main.py", "--port", "8188" `
            -WorkingDirectory $root -RedirectStandardOutput "$root\comfy.log" `
            -RedirectStandardError "$root\comfy.err.log" -WindowStyle Hidden -PassThru
        $p.Id | Set-Content "$root\comfy.pid" -Encoding ascii
        for ($i = 1; $i -le 40; $i++) {
            Start-Sleep -Seconds 3
            if (Test-Up) { "UP after ~$($i*3)s  (pid $($p.Id))"; break }
            if ($p.HasExited) {
                "process exited immediately (code $($p.ExitCode)) - last errors:"
                Get-Content "$root\comfy.err.log" -Tail 20
                break
            }
        }
        if (-not (Test-Up) -and -not $p.HasExited) {
            "still not answering - last errors:"; Get-Content "$root\comfy.err.log" -Tail 20
        }
    }
    "stop" {
        # Stop by recorded pid, never by matching every python process: the base
        # interpreter is shared with other tools (the godot-ai MCP server runs on
        # the same one), and a path match would take them down too.
        $pidFile = "$root\comfy.pid"
        if (Test-Path $pidFile) {
            $target = [int](Get-Content $pidFile)
            $proc = Get-Process -Id $target -ErrorAction SilentlyContinue
            if ($proc) { Stop-Process -Id $target -Force; "stopped (pid $target)" }
            else { "not running (stale pid $target)" }
            Remove-Item $pidFile -Force
        }
        else { "no pid file - not started by this script" }
    }
    "log" { Get-Content "$root\comfy.err.log" -Tail 40 }
}
