# Start / stop / check the local ComfyUI server used by generate_art.ps1.
#
#   .\tools\comfy.ps1 start
#   .\tools\comfy.ps1 status
#   .\tools\comfy.ps1 stop
#   .\tools\comfy.ps1 log

param([ValidateSet("start", "stop", "status", "log")][string]$Action = "status")

$root = "C:\Users\Administrador\ComfyUI"
$py = "$root\.venv\Scripts\python.exe"
$url = "http://127.0.0.1:8188"

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
        Start-Process -FilePath $py -ArgumentList "main.py", "--port", "8188" `
            -WorkingDirectory $root -RedirectStandardOutput "$root\comfy.log" `
            -RedirectStandardError "$root\comfy.err.log" -WindowStyle Hidden
        for ($i = 1; $i -le 40; $i++) {
            Start-Sleep -Seconds 3
            if (Test-Up) { "UP after ~$($i*3)s"; break }
        }
        if (-not (Test-Up)) { "failed to start - last errors:"; Get-Content "$root\comfy.err.log" -Tail 20 }
    }
    "stop" {
        Get-Process python -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -like "$root*" } |
            Stop-Process -Force
        "stopped"
    }
    "log" { Get-Content "$root\comfy.err.log" -Tail 40 }
}
