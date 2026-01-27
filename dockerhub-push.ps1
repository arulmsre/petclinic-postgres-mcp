# ============================================
# BULLETPROOF PETCLINIC BUILD + DOCKER PUSH
# ============================================

$services = @(
"spring-petclinic-config-server"
"spring-petclinic-discovery-server"
"spring-petclinic-api-gateway"
"spring-petclinic-customers-service"
"spring-petclinic-visits-service"
"spring-petclinic-vets-service"
"spring-petclinic-admin-server"
)

$version = "3.2.4"
$dockerfile = "docker/Dockerfile"

Write-Host "Starting full Petclinic build pipeline..."

foreach ($svc in $services) {

    Write-Host ""
    Write-Host "====================================="
    Write-Host "Building service: $svc"
    Write-Host "====================================="

    # Debug print to confirm svc is correct
    Write-Host "DEBUG: svc='$svc'"

    # 1. Validate folder exists
    if (!(Test-Path $svc)) {
        Write-Host "ERROR: Folder '$svc' not found. Skipping."
        continue
    }

    # 2. Build JAR
    Write-Host "Running Maven build..."
    mvn -f "$svc/pom.xml" clean package -DskipTests

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Maven build failed for $svc. Skipping."
        continue
    }

    # 3. Validate JAR exists
    $jarPath = "$svc/target/$svc-$version.jar"
    if (!(Test-Path $jarPath)) {
        Write-Host "ERROR: JAR not found: $jarPath"
        continue
    }

    Write-Host "JAR found: $jarPath"

    # 4. Build Docker image
    $imageName = "arul1985/$svc:latest"
    Write-Host "Building Docker image: $imageName"

    docker build `
        -t $imageName `
        --build-arg ARTIFACT_NAME="$svc-$version" `
        -f $dockerfile .

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Docker build failed for $svc. Skipping push."
        continue
    }

    Write-Host "Docker image built: $imageName"

    # 5. Push Docker image
    Write-Host "Pushing image to Docker Hub..."
    docker push $imageName

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Docker push failed for $svc."
        continue
    }

    Write-Host "Successfully built and pushed: $imageName"
}

Write-Host ""
Write-Host "All services processed."