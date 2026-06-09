$ErrorActionPreference = "Stop"

$statePath = Join-Path $PSScriptRoot ".k8s-portforwards.json"

if (-not (Test-Path $statePath)) {
    Write-Host "[INFO] No port-forward state file found at $statePath"
    exit 0
}

try {
    $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json

    foreach ($f in $state.forwards) {
        $pid = [int]$f.pid

        if ($pid -le 0) {
            continue
        }

        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($null -eq $proc) {
            Write-Host "[INFO] $($f.name) already stopped (PID $pid not found)."
            continue
        }

        Stop-Process -Id $pid -Force
        Write-Host "[OK] Stopped $($f.name) (PID $pid)." -ForegroundColor Green
    }

    Remove-Item -Path $statePath -Force
    Write-Host "[OK] Removed state file." -ForegroundColor Green
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
