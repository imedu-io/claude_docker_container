#!/bin/bash
# =============================================================================
# Claude Code Container Runner (Docker Compose)
# =============================================================================
#
# Run Claude Code for any project folder:
#   ./claude.sh my-project           # Folder in script directory
#   ./claude.sh ../other-project     # Relative path from current directory
#   ./claude.sh /path/to/project     # Absolute path
#
# =============================================================================

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
BUILD_FLAG=""
BUILD_CLAUDE_ONLY=""
BUILD_PROXY_ONLY=""
PROJECT_DIR=""

for arg in "$@"; do
    case $arg in
        --build)
            BUILD_FLAG="--build"
            ;;
        --build-claude)
            BUILD_CLAUDE_ONLY=1
            ;;
        --build-proxy)
            BUILD_PROXY_ONLY=1
            ;;
        *)
            if [ -z "$PROJECT_DIR" ]; then
                PROJECT_DIR="$arg"
            fi
            ;;
    esac
done

# Check if project directory argument is provided
if [ -z "$PROJECT_DIR" ]; then
    echo "Usage: ./claude.sh <project-path> [--build] [--build-claude] [--build-proxy]"
    echo ""
    echo "Options:"
    echo "  --build         Force rebuild of all Docker images (claude + proxy)"
    echo "  --build-claude  Force rebuild of the Claude container only"
    echo "  --build-proxy   Force rebuild of the proxy container only"
    echo ""
    echo "Examples:"
    echo "  ./claude.sh my-project              # Folder in script directory"
    echo "  ./claude.sh ../other-project        # Relative path"
    echo "  ./claude.sh /absolute/path          # Absolute path"
    echo "  ./claude.sh my-project --build      # Rebuild all images"
    echo "  ./claude.sh my-project --build-claude  # Rebuild Claude only"
    echo "  ./claude.sh my-project --build-proxy   # Rebuild proxy only"
    exit 1
fi

# Resolve project directory path
# Support: absolute paths, relative paths (from cwd), or folder names (relative to script)
if [[ "$PROJECT_DIR" = /* ]]; then
    # Absolute path
    PROJECT_PATH="$PROJECT_DIR"
elif [ -d "$PROJECT_DIR" ]; then
    # Relative path from current directory (e.g., ../my-project, ./foo)
    PROJECT_PATH="$(cd "$PROJECT_DIR" && pwd)"
elif [ -d "$SCRIPT_DIR/$PROJECT_DIR" ]; then
    # Folder name relative to script location
    PROJECT_PATH="$(cd "$SCRIPT_DIR/$PROJECT_DIR" && pwd)"
else
    echo "Error: Directory '$PROJECT_DIR' not found"
    echo "Looked in:"
    echo "  - $PROJECT_DIR (relative to current directory)"
    echo "  - $SCRIPT_DIR/$PROJECT_DIR (relative to script)"
    exit 1
fi

# Verify the resolved path exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Directory '$PROJECT_PATH' does not exist"
    exit 1
fi

# Extract just the folder name for container naming
PROJECT_NAME="$(basename "$PROJECT_PATH")"

# Check if required files exist
for file in docker-compose.yml Dockerfile.claude Dockerfile.proxy; do
    if [ ! -f "$SCRIPT_DIR/$file" ]; then
        echo "Error: $file not found in $SCRIPT_DIR"
        exit 1
    fi
done

# Check if proxy configuration exists
if [ ! -f "$SCRIPT_DIR/proxy/squid.conf" ] || [ ! -f "$SCRIPT_DIR/proxy/allowed-domains.txt" ]; then
    echo "Error: Proxy configuration not found in $SCRIPT_DIR/proxy/"
    exit 1
fi

# Generate unique instance ID for this session
INSTANCE_ID="${PROJECT_NAME}-$$"

# Export environment variables for docker-compose
export PROJECT_NAME
export PROJECT_PATH

# Change to script directory for docker-compose context
cd "$SCRIPT_DIR"

# Build images if requested
if [ -n "$BUILD_PROXY_ONLY" ]; then
    echo "Building proxy image only (no cache)..."
    docker compose build --no-cache proxy
elif [ -n "$BUILD_CLAUDE_ONLY" ]; then
    echo "Building Claude image only (no cache)..."
    docker compose build --no-cache claude
elif [ -n "$BUILD_FLAG" ]; then
    echo "Building images (no cache)..."
    docker compose build --no-cache
fi

# Ensure the docker network exists (external network must be created manually)
if ! docker network ls --format '{{.Name}}' | grep -q '^claude-network$'; then
    echo "Creating claude-network..."
    docker network create claude-network
fi

# Ensure shared proxy is running
if ! docker ps --format '{{.Names}}' | grep -q '^claude-shared-proxy$'; then
    echo "Starting shared proxy..."
    docker compose up -d proxy
    # Wait for proxy to be healthy
    echo "Waiting for proxy to be healthy..."
    for i in {1..30}; do
        if docker inspect claude-shared-proxy --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
            break
        fi
        sleep 1
    done
fi

# Run the containers
echo "Starting Claude Code with network filtering proxy..."
echo "Project: $PROJECT_NAME"
echo "Path: $PROJECT_PATH"
echo ""

# Use docker compose run for interactive session (not up)
# This allows proper TTY handling for the Claude CLI
# Use unique instance ID to allow multiple sessions for the same project
docker compose run --rm --service-ports --name "$INSTANCE_ID" claude

echo "Session ended. Shared proxy remains running for other sessions."
echo "To stop the proxy: docker stop claude-shared-proxy"
