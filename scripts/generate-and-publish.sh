#!/bin/bash

# generate-and-publish.sh
# Automated script to generate C# client from OpenAPI spec using Kiota and publish to Palantir Artifactory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Default values
SPEC_URL="${OPENAPI_SPEC_URL:-}"
SPEC_FILE=""
ARTIFACTORY_URL="${ARTIFACTORY_URL:-https://artifactory.palantir.com/artifactory}"
ARTIFACTORY_REPO="${ARTIFACTORY_REPO:-nuget-local}"
ARTIFACTORY_USERNAME="${ARTIFACTORY_USERNAME:-}"
ARTIFACTORY_API_KEY="${ARTIFACTORY_API_KEY:-}"
CLIENT_NAME="OpenApiClient"
NAMESPACE="OpenApiClient"
VERSION="1.0.0"
SKIP_GENERATION=false
SKIP_TESTS=false
SKIP_PUBLISH=false
USE_LOCAL_SPEC=false
CLEAN_OUTPUT=false

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --spec-url)
            SPEC_URL="$2"
            shift 2
            ;;
        --spec-file)
            SPEC_FILE="$2"
            shift 2
            ;;
        --artifactory-url)
            ARTIFACTORY_URL="$2"
            shift 2
            ;;
        --artifactory-repo)
            ARTIFACTORY_REPO="$2"
            shift 2
            ;;
        --username)
            ARTIFACTORY_USERNAME="$2"
            shift 2
            ;;
        --api-key)
            ARTIFACTORY_API_KEY="$2"
            shift 2
            ;;
        --client-name)
            CLIENT_NAME="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --skip-generation)
            SKIP_GENERATION=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --skip-publish)
            SKIP_PUBLISH=true
            shift
            ;;
        --use-local-spec)
            USE_LOCAL_SPEC=true
            shift
            ;;
        --clean-output)
            CLEAN_OUTPUT=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --spec-url URL          OpenAPI specification URL"
            echo "  --spec-file FILE        Local OpenAPI specification file"
            echo "  --artifactory-url URL   Artifactory base URL"
            echo "  --artifactory-repo REPO Artifactory repository name"
            echo "  --username USERNAME     Artifactory username"
            echo "  --api-key KEY           Artifactory API key"
            echo "  --client-name NAME      Generated client class name"
            echo "  --namespace NAME        Generated client namespace"
            echo "  --version VERSION       Package version"
            echo "  --skip-generation       Skip client generation"
            echo "  --skip-tests            Skip running tests"
            echo "  --skip-publish          Skip publishing to Artifactory"
            echo "  --use-local-spec        Use local demo spec file"
            echo "  --clean-output          Clean output directory before generation"
            echo "  --help                  Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${CYAN}========================================"
echo "Kiota C# Client Generation and Publishing"
echo "========================================${NC}"
echo ""

# Determine OpenAPI spec source
if [ "$USE_LOCAL_SPEC" = true ]; then
    if [ -z "$SPEC_FILE" ]; then
        SPEC_FILE="$PROJECT_ROOT/demo/openlibrary-openapi.json"
    fi
    if [ ! -f "$SPEC_FILE" ]; then
        echo -e "${RED}Error: Local spec file not found: $SPEC_FILE${NC}"
        exit 1
    fi
    SPEC_SOURCE="$SPEC_FILE"
    echo -e "${YELLOW}Using local spec: $SPEC_FILE${NC}"
else
    if [ -z "$SPEC_URL" ]; then
        SPEC_URL="https://openlibrary.org/static/openapi.json"
        echo -e "${YELLOW}Using default spec URL: $SPEC_URL${NC}"
    fi
    SPEC_SOURCE="$SPEC_URL"
    echo -e "${YELLOW}Using remote spec: $SPEC_URL${NC}"
fi

echo -e "${YELLOW}Client Name: $CLIENT_NAME${NC}"
echo -e "${YELLOW}Namespace: $NAMESPACE${NC}"
echo -e "${YELLOW}Version: $VERSION${NC}"
echo ""

# Step 1: Install/Update Kiota
echo -e "${GREEN}Step 1: Ensuring Kiota is installed...${NC}"
if ! command -v kiota &> /dev/null; then
    echo -e "${GRAY}  Installing Kiota...${NC}"
    dotnet tool install -g Microsoft.OpenApi.Kiota
    
    # Add to PATH if not already there
    export PATH="$PATH:$HOME/.dotnet/tools"
    echo -e "${GREEN}  ✓ Kiota installed successfully${NC}"
else
    echo -e "${GREEN}  ✓ Kiota is already installed${NC}"
    echo -e "${GRAY}  Updating to latest version...${NC}"
    dotnet tool update -g Microsoft.OpenApi.Kiota || true
fi

# Step 2: Generate Client Code
if [ "$SKIP_GENERATION" = false ]; then
    echo -e "\n${GREEN}Step 2: Generating C# Client with Kiota...${NC}"
    
    OUTPUT_PATH="$PROJECT_ROOT/src/$CLIENT_NAME/Generated"
    
    # Clean output directory if requested
    if [ "$CLEAN_OUTPUT" = true ] && [ -d "$OUTPUT_PATH" ]; then
        echo -e "${GRAY}  Cleaning output directory...${NC}"
        rm -rf "$OUTPUT_PATH"
    fi
    
    # Ensure output directory exists
    mkdir -p "$OUTPUT_PATH"
    
    # Generate the client
    echo -e "${GRAY}  Executing kiota generate command...${NC}"
    kiota generate \
        --language CSharp \
        --openapi "$SPEC_SOURCE" \
        --output "$OUTPUT_PATH" \
        --class-name "$CLIENT_NAME" \
        --namespace-name "$NAMESPACE" \
        --clean-output \
        --exclude-backward-compatible \
        --log-level Information
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ Generated client code successfully${NC}"
    else
        echo -e "${RED}Failed to generate client${NC}"
        exit 1
    fi
else
    echo -e "\n${YELLOW}Step 2: Skipping generation (using existing code)${NC}"
fi

# Step 3: Update Version
echo -e "\n${GREEN}Step 3: Updating Version...${NC}"
PROJECT_FILE="$PROJECT_ROOT/src/$CLIENT_NAME/$CLIENT_NAME.csproj"
if [ -f "$PROJECT_FILE" ]; then
    # Update version in project file using sed
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|<Version>.*</Version>|<Version>$VERSION</Version>|g" "$PROJECT_FILE"
        sed -i '' "s|<AssemblyVersion>.*</AssemblyVersion>|<AssemblyVersion>$VERSION</AssemblyVersion>|g" "$PROJECT_FILE"
        sed -i '' "s|<FileVersion>.*</FileVersion>|<FileVersion>$VERSION</FileVersion>|g" "$PROJECT_FILE"
    else
        # Linux
        sed -i "s|<Version>.*</Version>|<Version>$VERSION</Version>|g" "$PROJECT_FILE"
        sed -i "s|<AssemblyVersion>.*</AssemblyVersion>|<AssemblyVersion>$VERSION</AssemblyVersion>|g" "$PROJECT_FILE"
        sed -i "s|<FileVersion>.*</FileVersion>|<FileVersion>$VERSION</FileVersion>|g" "$PROJECT_FILE"
    fi
    echo -e "${GREEN}  ✓ Updated version to $VERSION${NC}"
else
    echo -e "${RED}Error: Project file not found: $PROJECT_FILE${NC}"
    exit 1
fi

# Step 4: Restore and Build
echo -e "\n${GREEN}Step 4: Building Project...${NC}"
cd "$PROJECT_ROOT"

echo -e "${GRAY}  Restoring packages...${NC}"
dotnet restore

echo -e "${GRAY}  Building solution...${NC}"
dotnet build --configuration Release --no-restore

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Build successful${NC}"
else
    echo -e "${RED}Build failed${NC}"
    exit 1
fi

# Step 5: Run Tests
if [ "$SKIP_TESTS" = false ]; then
    echo -e "\n${GREEN}Step 5: Running Tests...${NC}"
    TEST_PROJECT="$PROJECT_ROOT/test/$CLIENT_NAME.Tests/$CLIENT_NAME.Tests.csproj"
    
    if [ -f "$TEST_PROJECT" ]; then
        dotnet test --configuration Release --no-build --logger "trx;LogFileName=test-results.trx"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓ All tests passed${NC}"
        else
            echo -e "${RED}Tests failed${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}  ⚠ No test project found, skipping tests${NC}"
    fi
else
    echo -e "\n${YELLOW}Step 5: Skipping tests${NC}"
fi

# Step 6: Create NuGet Package
echo -e "\n${GREEN}Step 6: Creating NuGet Package...${NC}"
ARTIFACTS_PATH="$PROJECT_ROOT/artifacts"

# Clean artifacts directory
rm -rf "$ARTIFACTS_PATH"
mkdir -p "$ARTIFACTS_PATH"

dotnet pack "$PROJECT_FILE" \
    --configuration Release \
    --no-build \
    --output "$ARTIFACTS_PATH" \
    /p:PackageVersion="$VERSION"

if [ $? -eq 0 ]; then
    PACKAGE_PATH=$(ls $ARTIFACTS_PATH/*.nupkg | head -n 1)
    PACKAGE_SIZE=$(du -h "$PACKAGE_PATH" | cut -f1)
    echo -e "${GREEN}  ✓ Created package: $(basename $PACKAGE_PATH)${NC}"
    echo -e "${GRAY}    Size: $PACKAGE_SIZE${NC}"
else
    echo -e "${RED}Package creation failed${NC}"
    exit 1
fi

# Step 7: Publish to Artifactory
if [ "$SKIP_PUBLISH" = false ]; then
    echo -e "\n${GREEN}Step 7: Publishing to Palantir Artifactory...${NC}"
    
    if [ -z "$ARTIFACTORY_USERNAME" ] || [ -z "$ARTIFACTORY_API_KEY" ]; then
        echo -e "${YELLOW}  Warning: Artifactory credentials not provided. Skipping publish.${NC}"
        echo -e "${YELLOW}  Set ARTIFACTORY_USERNAME and ARTIFACTORY_API_KEY environment variables${NC}"
        echo -e "${YELLOW}  Or use --username and --api-key parameters${NC}"
    else
        # Configure NuGet source
        SOURCE_NAME="PalantirArtifactory"
        SOURCE_URL="$ARTIFACTORY_URL/api/nuget/$ARTIFACTORY_REPO"
        
        echo -e "${GRAY}  Configuring NuGet source...${NC}"
        echo -e "${GRAY}    URL: $SOURCE_URL${NC}"
        
        # Remove existing source if present
        dotnet nuget remove source "$SOURCE_NAME" 2>/dev/null || true
        
        # Add source with authentication
        dotnet nuget add source "$SOURCE_URL" \
            --name "$SOURCE_NAME" \
            --username "$ARTIFACTORY_USERNAME" \
            --password "$ARTIFACTORY_API_KEY" \
            --store-password-in-clear-text
        
        # Push package
        echo -e "${GRAY}  Publishing package...${NC}"
        dotnet nuget push "$PACKAGE_PATH" \
            --source "$SOURCE_NAME" \
            --api-key "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_API_KEY}" \
            --skip-duplicate \
            --timeout 600
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓ Successfully published to Artifactory${NC}"
            echo ""
            echo -e "${CYAN}  Package URL:${NC}"
            echo -e "  $ARTIFACTORY_URL/webapp/#/artifacts/browse/tree/General/$ARTIFACTORY_REPO/$NAMESPACE/$VERSION"
        else
            echo -e "${RED}Failed to publish package${NC}"
            exit 1
        fi
        
        # Clean up NuGet source
        dotnet nuget remove source "$SOURCE_NAME" 2>/dev/null || true
    fi
else
    echo -e "\n${YELLOW}Step 7: Skipping publish${NC}"
fi

# Step 8: Clean up
echo -e "\n${GREEN}Step 8: Cleaning up...${NC}"
if [ -d "$ARTIFACTS_PATH" ]; then
    echo -e "${GRAY}  Artifacts saved in: $ARTIFACTS_PATH${NC}"
fi
echo -e "${GREEN}  ✓ Done${NC}"

echo -e "\n${CYAN}========================================"
echo -e "${GREEN}✓ Build Complete!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${CYAN}Summary:${NC}"
echo -e "  • Client Name: $CLIENT_NAME"
echo -e "  • Namespace: $NAMESPACE"
echo -e "  • Version: $VERSION"
echo -e "  • Package: $(basename $PACKAGE_PATH)"
if [ "$SKIP_PUBLISH" = false ] && [ -n "$ARTIFACTORY_USERNAME" ]; then
    echo -e "  • Published to: $SOURCE_URL"
fi
echo ""