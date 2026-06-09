param(
    [Parameter(Mandatory = $false)]
    [string]$KubeStateNamespace = "kube-system",

    [Parameter(Mandatory = $false)]
    [string]$KubeStateService = "kube-state-metrics",

    [Parameter(Mandatory = $false)]
    [string]$KubeStateMapping = "8085:8080",

    [Parameter(Mandatory = $false)]
    [string]$KubeletNamespace = "kube-system",

    [Parameter(Mandatory = $false)]
    [string]$KubeletPod = "",

    [Parameter(Mandatory = $false)]
    [string]$KubeletService = "metrics-server",

    [Parameter(Mandatory = $false)]
    [string]$KubeletMapping = "8086:10250"
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor DarkYellow
}

function Test-PortInUse {
    param([int]$Port)
    $line = netstat -ano | Select-String ":$Port\s"
    return ($null -ne $line)
}

function Start-PortForwardProcess {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    $exe = "kubectl"
    $argString = ($Arguments -join " ")

    Write-Info "Starting $Name: $exe $argString"

    $proc = Start-Process -FilePath $exe -ArgumentList $Arguments -WindowStyle Hidden -PassThru

    Start-Sleep -Seconds 2

    if ($proc.HasExited) {
        throw "$Name failed to start. Check kubectl context/permissions and target resource names."
    }

    return $proc
}

try {
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        throw "kubectl is not installed or not in PATH."
    }

    $statePath = Join-Path $PSScriptRoot ".k8s-portforwards.json"

    # If previous run exists, stop it first to avoid duplicate forwards.
    if (Test-Path $statePath) {
        Write-Warn "Existing port-forward state found. Stopping previous forwards first."
        & (Join-Path $PSScriptRoot "stop-k8s-portforwards.ps1") | Out-Null
    }

    $kubeStateLocalPort = [int](($KubeStateMapping -split ":")[0])
    $kubeletLocalPort = [int](($KubeletMapping -split ":")[0])

    if (Test-PortInUse -Port $kubeStateLocalPort) {
        throw "Port $kubeStateLocalPort is already in use."
    }

    if (Test-PortInUse -Port $kubeletLocalPort) {
        throw "Port $kubeletLocalPort is already in use."
    }

    $kubeStateArgs = @("-n", $KubeStateNamespace, "port-forward", "svc/$KubeStateService", $KubeStateMapping)
    $kubeStateProc = Start-PortForwardProcess -Name "kube-state-metrics" -Arguments $kubeStateArgs

    $kubeletTarget = if ([string]::IsNullOrWhiteSpace($KubeletPod)) { "svc/$KubeletService" } else { "pod/$KubeletPod" }
    $kubeletArgs = @("-n", $KubeletNamespace, "port-forward", $kubeletTarget, $KubeletMapping)
    $kubeletProc = Start-PortForwardProcess -Name "kubelet-cadvisor" -Arguments $kubeletArgs

    $state = [ordered]@{
        startedAt = (Get-Date).ToString("s")
        forwards  = @(
            [ordered]@{
                name      = "kube-state-metrics"
                pid       = $kubeStateProc.Id
                namespace = $KubeStateNamespace
                target    = "svc/$KubeStateService"
                mapping   = $KubeStateMapping
            },
            [ordered]@{
                name      = "kubelet-cadvisor"
                pid       = $kubeletProc.Id
                namespace = $KubeletNamespace
                target    = $kubeletTarget
                mapping   = $KubeletMapping
            }
        )
    }

    $state | ConvertTo-Json -Depth 6 | Set-Content -Path $statePath -Encoding UTF8

    Write-Ok "Port-forwards started."
    Write-Host ""
    Write-Host "  kube-state-metrics -> localhost:$kubeStateLocalPort"
    Write-Host "  kubelet-cadvisor   -> localhost:$kubeletLocalPort"
    Write-Host ""
    Write-Host "State file: $statePath"
    Write-Host "Use scripts/stop-k8s-portforwards.ps1 to stop them."
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
