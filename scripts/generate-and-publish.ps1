# generate-and-publish.ps1
# Automated script to generate C# client from OpenAPI spec using Kiota and publish to Palantir Artifactory

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SpecUrl = $env:OPENAPI_SPEC_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$SpecFile = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ArtifactoryUrl = $env:ARTIFACTORY_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$ArtifactoryRepo = "nuget-local",
    
    [Parameter(Mandatory=$false)]
    [string]$ArtifactoryUsername = $env:ARTIFACTORY_USERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$ArtifactoryApiKey = $env:ARTIFACTORY_API_KEY,
    
    [Parameter(Mandatory=$false)]
    [string]$ClientName = "OpenApiClient",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "OpenApiClient",
    
    [Parameter(Mandatory=$false)]
    [string]$Version = "1.0.0",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipGeneration,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTests,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPublish,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseLocalSpec,
    
    [Parameter(Mandatory=$false)]
    [switch]$CleanOutput
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Script root directory
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Kiota C# Client Generation and Publishing" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Determine OpenAPI spec source
if ($UseLocalSpec) {
    if (-not $SpecFile) {
        $SpecFile = Join-Path $ProjectRoot "demo" "openlibrary-openapi.json"
    }
    if (-not (Test-Path $SpecFile)) {
        Write-Error "Local spec file not found: $SpecFile"
        exit 1
    }
    $SpecSource = $SpecFile
    Write-Host "Using local spec: $SpecFile" -ForegroundColor Yellow
}
else {
    if (-not $SpecUrl) {
        $SpecUrl = "https://openlibrary.org/static/openapi.json"
        Write-Host "Using default spec URL: $SpecUrl" -ForegroundColor Yellow
    }
    $SpecSource = $SpecUrl
    Write-Host "Using remote spec: $SpecUrl" -ForegroundColor Yellow
}

Write-Host "Client Name: $ClientName" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host ""

# Step 1: Install/Update Kiota
Write-Host "Step 1: Ensuring Kiota is installed..." -ForegroundColor Green
try {
    $kiotaVersion = dotnet tool list -g | Select-String "microsoft.openapi.kiota"
    
    if ($kiotaVersion) {
        Write-Host "  ✓ Kiota is already installed: $kiotaVersion" -ForegroundColor Green
        Write-Host "  Updating to latest version..." -ForegroundColor Gray
        dotnet tool update -g Microsoft.OpenApi.Kiota | Out-Null
    }
    else {
        Write-Host "  Installing Kiota..." -ForegroundColor Gray
        dotnet tool install -g Microsoft.OpenApi.Kiota
        Write-Host "  ✓ Kiota installed successfully" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to install/update Kiota: $_"
    exit 1
}

# Step 2: Generate Client Code
if (-not $SkipGeneration) {
    Write-Host "`nStep 2: Generating C# Client with Kiota..." -ForegroundColor Green
    
    $outputPath = Join-Path $ProjectRoot "src" $ClientName "Generated"
    
    # Clean output directory if requested
    if ($CleanOutput -and (Test-Path $outputPath)) {
        Write-Host "  Cleaning output directory..." -ForegroundColor Gray
        Remove-Item -Recurse -Force $outputPath
    }
    
    # Ensure output directory exists
    if (-not (Test-Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    }
    
    # Build Kiota command
    $kiotaArgs = @(
        "generate",
        "--language", "CSharp",
        "--openapi", $SpecSource,
        "--output", $outputPath,
        "--class-name", $ClientName,
        "--namespace-name", $Namespace,
        "--clean-output",
        "--exclude-backward-compatible",
        "--log-level", "Information"
    )
    
    Write-Host "  Executing: kiota $($kiotaArgs -join ' ')" -ForegroundColor Gray
    
    try {
        & kiota $kiotaArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Generated client code successfully" -ForegroundColor Green
        }
        else {
            throw "Kiota generation failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Error "Failed to generate client: $_"
        exit 1
    }
}
else {
    Write-Host "`nStep 2: Skipping generation (using existing code)" -ForegroundColor Yellow
}

# Step 3: Update Version
Write-Host "`nStep 3: Updating Version..." -ForegroundColor Green
$projectFile = Join-Path $ProjectRoot "src" $ClientName "$ClientName.csproj"
if (Test-Path $projectFile) {
    $xml = [xml](Get-Content $projectFile)
    $xml.Project.PropertyGroup.Version = $Version
    $xml.Project.PropertyGroup.AssemblyVersion = $Version
    $xml.Project.PropertyGroup.FileVersion = $Version
    $xml.Save($projectFile)
    Write-Host "  ✓ Updated version to $Version" -ForegroundColor Green
}
else {
    Write-Error "Project file not found: $projectFile"
    exit 1
}

# Step 4: Restore and Build
Write-Host "`nStep 4: Building Project..." -ForegroundColor Green
try {
    Push-Location $ProjectRoot
    
    Write-Host "  Restoring packages..." -ForegroundColor Gray
    dotnet restore
    
    Write-Host "  Building solution..." -ForegroundColor Gray
    dotnet build --configuration Release --no-restore
    
    Write-Host "  ✓ Build successful" -ForegroundColor Green
}
catch {
    Write-Error "Build failed: $_"
    exit 1
}
finally {
    Pop-Location
}

# Step 5: Run Tests
if (-not $SkipTests) {
    Write-Host "`nStep 5: Running Tests..." -ForegroundColor Green
    $testProject = Join-Path $ProjectRoot "test" "$ClientName.Tests" "$ClientName.Tests.csproj"
    
    if (Test-Path $testProject) {
        try {
            Push-Location $ProjectRoot
            dotnet test --configuration Release --no-build --logger "trx;LogFileName=test-results.trx"
            Write-Host "  ✓ All tests passed" -ForegroundColor Green
        }
        catch {
            Write-Error "Tests failed: $_"
            exit 1
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Host "  ⚠ No test project found, skipping tests" -ForegroundColor Yellow
    }
}
else {
    Write-Host "`nStep 5: Skipping tests" -ForegroundColor Yellow
}

# Step 6: Create NuGet Package
Write-Host "`nStep 6: Creating NuGet Package..." -ForegroundColor Green
try {
    Push-Location $ProjectRoot
    
    # Clean artifacts directory
    $artifactsPath = Join-Path $ProjectRoot "artifacts"
    if (Test-Path $artifactsPath) {
        Remove-Item -Recurse -Force $artifactsPath
    }
    New-Item -ItemType Directory -Path $artifactsPath | Out-Null
    
    dotnet pack $projectFile `
        --configuration Release `
        --no-build `
        --output $artifactsPath `
        /p:PackageVersion=$Version
    
    $packagePath = Get-ChildItem "$artifactsPath\*.nupkg" | Select-Object -First 1
    Write-Host "  ✓ Created package: $($packagePath.Name)" -ForegroundColor Green
    Write-Host "    Size: $([math]::Round($packagePath.Length / 1MB, 2)) MB" -ForegroundColor Gray
}
catch {
    Write-Error "Package creation failed: $_"
    exit 1
}
finally {
    Pop-Location
}

# Step 7: Publish to Artifactory
if (-not $SkipPublish) {
    Write-Host "`nStep 7: Publishing to Palantir Artifactory..." -ForegroundColor Green
    
    if (-not $ArtifactoryUrl) {
        $ArtifactoryUrl = "https://artifactory.palantir.com/artifactory"
    }
    
    if (-not $ArtifactoryUsername -or -not $ArtifactoryApiKey) {
        Write-Warning "Artifactory credentials not provided. Skipping publish."
        Write-Host "  Set ARTIFACTORY_USERNAME and ARTIFACTORY_API_KEY environment variables" -ForegroundColor Yellow
        Write-Host "  Or use -ArtifactoryUsername and -ArtifactoryApiKey parameters" -ForegroundColor Yellow
    }
    else {
        # Configure NuGet source
        $sourceName = "PalantirArtifactory"
        $sourceUrl = "$ArtifactoryUrl/api/nuget/$ArtifactoryRepo"
        
        Write-Host "  Configuring NuGet source..." -ForegroundColor Gray
        Write-Host "    URL: $sourceUrl" -ForegroundColor Gray
        
        # Remove existing source if present
        dotnet nuget remove source $sourceName 2>$null
        
        # Add source with authentication
        dotnet nuget add source $sourceUrl `
            --name $sourceName `
            --username $ArtifactoryUsername `
            --password $ArtifactoryApiKey `
            --store-password-in-clear-text
        
        # Push package
        Write-Host "  Publishing package..." -ForegroundColor Gray
        try {
            dotnet nuget push $packagePath.FullName `
                --source $sourceName `
                --api-key "${ArtifactoryUsername}:${ArtifactoryApiKey}" `
                --skip-duplicate `
                --timeout 600
            
            Write-Host "  ✓ Successfully published to Artifactory" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Package URL:" -ForegroundColor Cyan
            Write-Host "  $ArtifactoryUrl/webapp/#/artifacts/browse/tree/General/$ArtifactoryRepo/$Namespace/$Version" -ForegroundColor White
        }
        catch {
            Write-Error "Failed to publish package: $_"
            exit 1
        }
        finally {
            # Clean up NuGet source
            dotnet nuget remove source $sourceName 2>$null
        }
    }
}
else {
    Write-Host "`nStep 7: Skipping publish" -ForegroundColor Yellow
}

# Step 8: Clean up
Write-Host "`nStep 8: Cleaning up..." -ForegroundColor Green
if (Test-Path $artifactsPath) {
    # Keep artifacts for debugging if needed
    Write-Host "  Artifacts saved in: $artifactsPath" -ForegroundColor Gray
}
Write-Host "  ✓ Done" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✓ Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  • Client Name: $ClientName" -ForegroundColor White
Write-Host "  • Namespace: $Namespace" -ForegroundColor White
Write-Host "  • Version: $Version" -ForegroundColor White
Write-Host "  • Package: $($packagePath.Name)" -ForegroundColor White
if (-not $SkipPublish -and $ArtifactoryUsername) {
    Write-Host "  • Published to: $sourceUrl" -ForegroundColor White
}
Write-Host ""