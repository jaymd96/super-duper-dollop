# 📝 Terminal Commands Reference

This document contains all the commands executed during the setup and development of this Kiota tutorial repository.

## 🔧 Initial Setup Commands

### .NET Project Creation
```bash
# Create directory structure
mkdir -p OpenApiClient/{src/OpenApiClient/{Generated,Extensions},scripts,test/OpenApiClient.Tests,demo,.github/workflows}

# Initialize .NET solution
cd OpenApiClient
dotnet new sln -n OpenApiClient

# Create class library project
dotnet new classlib -o src/OpenApiClient -n OpenApiClient -f net9.0

# Create test project
dotnet new xunit -o test/OpenApiClient.Tests -n OpenApiClient.Tests -f net9.0

# Add projects to solution
dotnet sln add src/OpenApiClient/OpenApiClient.csproj test/OpenApiClient.Tests/OpenApiClient.Tests.csproj

# Create console test app
dotnet new console -o demo/TestClient -n TestClient -f net9.0
dotnet sln add demo/TestClient/TestClient.csproj
```

## 🛠️ Kiota Installation & Setup
```bash
# Install Kiota globally
dotnet tool install -g Microsoft.OpenApi.Kiota

# Update Kiota to latest version
dotnet tool update -g Microsoft.OpenApi.Kiota

# Check Kiota version
kiota --version

# Set environment variables for Kiota (macOS/Linux)
export PATH="$PATH:$HOME/.dotnet/tools"
export DOTNET_ROOT=$HOME/.dotnet
```

## 📥 Download OpenAPI Specifications
```bash
# Download OpenLibrary OpenAPI spec
curl -o demo/openlibrary-openapi.json https://openlibrary.org/static/openapi.json

# Get sample API response for schema design
curl -s "https://openlibrary.org/search.json?q=The+Lord+of+the+Rings&limit=1" | jq '.' | head -50
curl -s "https://openlibrary.org/authors/OL26320A.json" | jq '.' | head -30
```

## 🚀 Kiota Client Generation
```bash
# Generate UNTYPED client (from original spec with empty schemas)
kiota generate \
  --language CSharp \
  --openapi demo/openlibrary-openapi.json \
  --output src/OpenApiClient/Generated \
  --class-name OpenApiClient \
  --namespace-name OpenApiClient \
  --clean-output \
  --exclude-backward-compatible \
  --log-level Information

# Generate TYPED client (from enhanced spec with proper schemas)
kiota generate \
  --language CSharp \
  --openapi demo/openlibrary-enhanced.json \
  --output src/OpenApiClient/GeneratedTyped \
  --class-name OpenApiClientTyped \
  --namespace-name OpenApiClient.Typed \
  --clean-output \
  --exclude-backward-compatible \
  --log-level Information
```

## 🏗️ Build & Test Commands
```bash
# Restore NuGet packages
dotnet restore

# Build the solution
dotnet build --configuration Release

# Build specific project
dotnet build src/OpenApiClient/OpenApiClient.csproj --configuration Release
dotnet build demo/TestClient/TestClient.csproj --configuration Release

# Run tests
dotnet test --configuration Release --logger "console;verbosity=normal"
dotnet test --configuration Release --logger "console;verbosity=minimal"

# Run the test client
dotnet run --project demo/TestClient/TestClient.csproj --configuration Release

# Create NuGet package
dotnet pack src/OpenApiClient/OpenApiClient.csproj \
  --configuration Release \
  --output ./artifacts \
  /p:PackageVersion=1.0.1
```

## 📊 File Inspection Commands
```bash
# List generated files
ls -la src/OpenApiClient/Generated/
ls -la src/OpenApiClient/GeneratedTyped/Models/

# Check generated model files
ls -la src/OpenApiClient/GeneratedTyped/Models/

# Find response definitions in OpenAPI spec
grep -n "responses" demo/openlibrary-openapi.json | head -20
grep -n "components" demo/openlibrary-openapi.json
grep -A 10 '"/search.json"' demo/openlibrary-openapi.json

# List all API endpoints in spec
jq '.paths | keys' demo/openlibrary-openapi.json
```

## 🔄 Automation Scripts
```bash
# Run PowerShell generation script
pwsh scripts/generate-and-publish.ps1 \
  --use-local-spec \
  --skip-publish \
  --version 1.0.0-demo

# Run Bash generation script
bash scripts/generate-and-publish.sh \
  --use-local-spec \
  --skip-publish \
  --skip-tests \
  --version 1.0.1

# Make bash script executable
chmod +x scripts/generate-and-publish.sh
```

## 📦 Git Commands
```bash
# Initialize repository
git init

# Create and switch branches
git checkout -b demo
git checkout main

# Add and commit files
git add -A
git commit -m "Initial commit: Complete Kiota tutorial with typed and untyped examples"
git commit -m "Add comprehensive tutorial with typed vs untyped examples"
git commit -m "Add tutorial summary and key takeaways"

# Add remote and push
git remote add origin git@github.com:jaymd96/super-duper-dollop.git
git push -u origin main
git push origin demo
```

## 🔍 Troubleshooting Commands
```bash
# Check .NET installation
dotnet --info

# Check current directory
pwd && ls -la

# Remove default test file
rm test/OpenApiClient.Tests/UnitTest1.cs

# Clean build artifacts
dotnet clean
rm -rf bin/ obj/
rm -rf artifacts/
```

## 🎯 Quick Reference

### Generate Typed Client (One Command)
```bash
export PATH="$PATH:$HOME/.dotnet/tools" && \
export DOTNET_ROOT=$HOME/.dotnet && \
kiota generate \
  --language CSharp \
  --openapi demo/openlibrary-enhanced.json \
  --output src/TypedClient \
  --class-name MyApiClient \
  --namespace-name MyApi.Client \
  --clean-output \
  --exclude-backward-compatible
```

### Build and Run Test Client (One Command)
```bash
dotnet build && dotnet run --project demo/TestClient
```

### Full Pipeline (Generate, Build, Test)
```bash
# Generate client
kiota generate --language CSharp --openapi demo/openlibrary-enhanced.json --output src/Generated --namespace MyApi

# Build solution
dotnet build --configuration Release

# Run tests
dotnet test --configuration Release

# Run demo
dotnet run --project demo/TestClient --configuration Release
```

## 📌 Environment Variables Used
```bash
# Kiota and .NET
export PATH="$PATH:$HOME/.dotnet/tools"
export DOTNET_ROOT=$HOME/.dotnet

# Artifactory (for publishing)
export OPENAPI_SPEC_URL="https://openlibrary.org/static/openapi.json"
export ARTIFACTORY_URL="https://artifactory.palantir.com/artifactory"
export ARTIFACTORY_USERNAME="your-username"
export ARTIFACTORY_API_KEY="your-api-key"
```

## 💡 Tips
- Always run `export PATH="$PATH:$HOME/.dotnet/tools"` before using Kiota if it's not in your PATH
- Use `--clean-output` flag with Kiota to ensure fresh generation
- Add `--log-level Debug` to Kiota commands for troubleshooting
- Use `--exclude-backward-compatible` to reduce generated code size
- Always specify `--namespace-name` to avoid conflicts

---

This reference contains every command used to create this tutorial repository. Save this for future reference when working with Kiota!