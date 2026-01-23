# Run JMeter Load Test Script for Petclinic
# Usage: .\run-load-test.ps1 -Scenario <light|medium|heavy|stress> -Target <local|external>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("light", "medium", "heavy", "stress", "custom")]
    [string]$Scenario = "light",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("local", "external")]
    [string]$Target = "local",
    
    [Parameter(Mandatory=$false)]
    [int]$Threads = 0,
    
    [Parameter(Mandatory=$false)]
    [int]$RampTime = 0,
    
    [Parameter(Mandatory=$false)]
    [int]$Duration = 0,
    
    [Parameter(Mandatory=$false)]
    [string]$CustomHost = "",
    
    [Parameter(Mandatory=$false)]
    [int]$CustomPort = 8080
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Petclinic JMeter Load Test Runner" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if JMeter is installed
try {
    $jmeterVersion = jmeter --version 2>&1 | Select-String "Apache JMeter"
    Write-Host "[OK] JMeter installed: $jmeterVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] JMeter not found. Please install Apache JMeter first." -ForegroundColor Red
    Write-Host "See: jmeter/JMETER-LOAD-TESTING-GUIDE.md for installation instructions`n" -ForegroundColor Yellow
    exit 1
}

# Create results directory
if (!(Test-Path "results")) {
    New-Item -ItemType Directory -Path "results" -Force | Out-Null
}

# Define scenario parameters
$scenarios = @{
    light = @{
        threads = 5
        ramptime = 30
        duration = 180
        description = "Light Load - 5 users, 3 minutes"
    }
    medium = @{
        threads = 20
        ramptime = 120
        duration = 600
        description = "Medium Load - 20 users, 10 minutes"
    }
    heavy = @{
        threads = 100
        ramptime = 300
        duration = 1800
        description = "Heavy Load - 100 users, 30 minutes"
    }
    stress = @{
        threads = 200
        ramptime = 600
        duration = 3600
        description = "Stress Test - 200 users, 60 minutes"
    }
    custom = @{
        threads = $Threads
        ramptime = $RampTime
        duration = $Duration
        description = "Custom - $Threads users, $Duration seconds"
    }
}

# Validate custom scenario
if ($Scenario -eq "custom") {
    if ($Threads -eq 0 -or $Duration -eq 0) {
        Write-Host "[ERROR] For custom scenario, provide -Threads and -Duration" -ForegroundColor Red
        Write-Host "Example: .\run-load-test.ps1 -Scenario custom -Threads 50 -Duration 600`n" -ForegroundColor Yellow
        exit 1
    }
    if ($RampTime -eq 0) {
        $RampTime = [Math]::Floor($Threads / 2)
        $scenarios.custom.ramptime = $RampTime
        Write-Host "[INFO] Auto-calculated RampTime: $RampTime seconds" -ForegroundColor Yellow
    }
}

$config = $scenarios[$Scenario]

# Determine target host and port
$targetHost = ""
$targetPort = 8080
$protocol = "http"

if ($CustomHost -ne "") {
    $targetHost = $CustomHost
    $targetPort = $CustomPort
    Write-Host "[CONFIG] Using custom host: $CustomHost`:$CustomPort" -ForegroundColor Yellow
} elseif ($Target -eq "local") {
    Write-Host "[CONFIG] Target: Local (port-forward required)" -ForegroundColor Yellow
    $targetHost = "localhost"
    $targetPort = 8080
    
    # Check if port-forward is running
    $portOpen = Test-NetConnection -ComputerName localhost -Port 8080 -InformationLevel Quiet -WarningAction SilentlyContinue
    if (!$portOpen) {
        Write-Host "`n[WARNING] Port 8080 not accessible!" -ForegroundColor Yellow
        Write-Host "Start port-forwarding in another terminal:" -ForegroundColor Yellow
        Write-Host "  kubectl port-forward -n petclinic service/api-gateway 8080:8080`n" -ForegroundColor White
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            exit 0
        }
    } else {
        Write-Host "[OK] Port 8080 is accessible" -ForegroundColor Green
    }
} elseif ($Target -eq "external") {
    Write-Host "[CONFIG] Target: External LoadBalancer" -ForegroundColor Yellow
    
    # Get external IP
    try {
        $externalIP = kubectl get svc api-gateway -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $externalIP) {
            $targetHost = $externalIP
            $targetPort = 8080
            Write-Host "[OK] External IP: $externalIP" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Failed to get external IP. Ensure service is LoadBalancer type." -ForegroundColor Red
            Write-Host "Run: kubectl patch svc api-gateway -n petclinic -p '{`"spec`":{`"type`":`"LoadBalancer`"}}'`n" -ForegroundColor Yellow
            exit 1
        }
    } catch {
        Write-Host "[ERROR] kubectl command failed. Ensure kubectl is configured.`n" -ForegroundColor Red
        exit 1
    }
}

# Display test configuration
Write-Host "`n[TEST CONFIGURATION]" -ForegroundColor Cyan
Write-Host "Scenario:    $($config.description)" -ForegroundColor White
Write-Host "Target:      $protocol`://$targetHost`:$targetPort" -ForegroundColor White
Write-Host "Threads:     $($config.threads) virtual users" -ForegroundColor White
Write-Host "Ramp Time:   $($config.ramptime) seconds" -ForegroundColor White
Write-Host "Duration:    $($config.duration) seconds ($([Math]::Round($config.duration/60, 1)) minutes)" -ForegroundColor White

# Generate result file name
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resultFile = "results\$Scenario-$Target-$timestamp.jtl"
$htmlReport = "results\$Scenario-$Target-$timestamp-html"

Write-Host "Results:     $resultFile" -ForegroundColor White
Write-Host "HTML Report: $htmlReport`n" -ForegroundColor White

# Confirm before running
Write-Host "[READY] Press Enter to start load test or Ctrl+C to cancel..." -ForegroundColor Yellow
Read-Host

Write-Host "`n[STARTING] JMeter load test...`n" -ForegroundColor Green

# Build JMeter arguments array
$jmeterArgs = @(
    '-n',
    '-t', 'petclinic-load-test.jmx',
    "-Jhost=$targetHost",
    "-Jport=$targetPort",
    "-Jprotocol=$protocol",
    "-Jthreads=$($config.threads)",
    "-Jramptime=$($config.ramptime)",
    "-Jduration=$($config.duration)",
    '-l', $resultFile,
    '-e',
    '-o', $htmlReport
)

# Run JMeter
Write-Host "[RUNNING] jmeter $($jmeterArgs -join ' ')`n" -ForegroundColor Cyan
& jmeter $jmeterArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  Load Test Completed Successfully!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green
    
    Write-Host "[RESULTS]" -ForegroundColor Cyan
    Write-Host "  JTL File:     $resultFile" -ForegroundColor White
    Write-Host "  HTML Report:  $htmlReport\index.html`n" -ForegroundColor White
    
    # Open HTML report
    $openReport = Read-Host "Open HTML report in browser? (Y/n)"
    if ($openReport -ne "n" -and $openReport -ne "N") {
        Start-Process "$htmlReport\index.html"
    }
    
    # Show quick summary
    Write-Host "`n[QUICK SUMMARY]" -ForegroundColor Cyan
    if (Test-Path $resultFile) {
        $lines = Get-Content $resultFile | Measure-Object -Line
        $errors = Get-Content $resultFile | Select-String "false" | Measure-Object -Line
        $totalRequests = $lines.Lines - 1  # Exclude header
        $errorCount = $errors.Lines
        $successRate = [Math]::Round((($totalRequests - $errorCount) / $totalRequests) * 100, 2)
        
        Write-Host "  Total Requests: $totalRequests" -ForegroundColor White
        Write-Host "  Errors:         $errorCount" -ForegroundColor $(if($errorCount -eq 0){"Green"}else{"Red"})
        Write-Host "  Success Rate:   $successRate%`n" -ForegroundColor $(if($successRate -ge 99){"Green"}elseif($successRate -ge 95){"Yellow"}else{"Red"})
    }
    
    Write-Host "[NEXT STEPS]" -ForegroundColor Cyan
    Write-Host "  1. Review HTML report for detailed metrics" -ForegroundColor White
    Write-Host "  2. Check Prometheus metrics: http://localhost:9090" -ForegroundColor White
    Write-Host "  3. View Grafana dashboards: http://20.81.80.200" -ForegroundColor White
    Write-Host "  4. Analyze pod metrics: kubectl top pods -n petclinic`n" -ForegroundColor White
    
} else {
    Write-Host "`n[ERROR] Load test failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Check jmeter.log for details`n" -ForegroundColor Yellow
    exit 1
}
