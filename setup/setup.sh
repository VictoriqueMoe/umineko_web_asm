#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

DEFAULT_GAME_PATH="./game"
DEFAULT_PORT="8080"

print_banner() {
    echo ""
    echo "=========================================="
    echo "  Umineko Web - Setup"
    echo "=========================================="
    echo ""
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Error: Docker is not installed."
        echo "Install it from https://docs.docker.com/get-docker/"
        exit 1
    fi
    if ! docker info &>/dev/null; then
        echo "Error: Docker is not running. Please start Docker and try again."
        exit 1
    fi
    if ! docker compose version &>/dev/null; then
        echo "Error: Docker Compose is not available."
        echo "It should be included with Docker Desktop."
        exit 1
    fi
}

check_existing() {
    if [ -f "docker-compose.override.yml" ]; then
        echo "Existing installation detected."
        echo ""
        echo "  1) Update    - Pull latest changes and rebuild"
        echo "  2) Configure - Re-run setup with new settings"
        echo ""
        while true; do
            read -rp "Choose [1/2] (default: 1): " choice
            choice="${choice:-1}"
            if [ "$choice" = "1" ]; then
                do_update
                exit 0
            elif [ "$choice" = "2" ]; then
                return
            else
                echo "Please enter 1 or 2."
            fi
        done
    fi
}

do_update() {
    echo ""
    echo "Pulling latest changes..."
    git pull
    echo ""
    docker compose down 2>/dev/null || true
    echo "Rebuilding..."
    echo ""
    docker compose build --build-arg "ONS_CACHE_BUST=$(date +%s)"
    docker compose up -d

    local port
    port=$(grep -oP '"\K[0-9]+(?=:80")' docker-compose.override.yml 2>/dev/null || echo "8080")

    echo ""
    echo "=========================================="
    echo "  Umineko Web updated!"
    echo "=========================================="
    echo ""
    echo "  URL: http://localhost:${port}"
    echo ""
}

ask_hosting_mode() {
    echo "How do you want to run Umineko Web?"
    echo ""
    echo "  1) Local      - Serves original game files directly (fast startup)"
    echo "  2) Production - Converts assets for smaller file sizes (PNG->WebP,"
    echo "                  MP4->WebM, OGG re-encoding). Takes a while on first run."
    echo ""
    while true; do
        read -rp "Choose [1/2] (default: 1): " mode_choice
        mode_choice="${mode_choice:-1}"
        if [ "$mode_choice" = "1" ]; then
            HOSTING_MODE="local"
            break
        elif [ "$mode_choice" = "2" ]; then
            HOSTING_MODE="production"
            break
        else
            echo "Please enter 1 or 2."
        fi
    done
    echo ""
}

ask_game_path() {
    echo "Where are your Umineko game files?"
    read -rp "Path (default: $DEFAULT_GAME_PATH): " game_path
    game_path="${game_path:-$DEFAULT_GAME_PATH}"

    game_path="${game_path/#\~/$HOME}"

    if [[ "$game_path" =~ ^[A-Za-z]:[/\\] ]] && command -v wslpath &>/dev/null; then
        game_path="$(wslpath -u "$game_path")"
    elif [[ ! "$game_path" = /* ]]; then
        game_path="$(cd "$(dirname "$game_path")" 2>/dev/null && pwd)/$(basename "$game_path")"
    fi

    if [ ! -d "$game_path" ]; then
        echo "Error: Directory '$game_path' does not exist."
        exit 1
    fi

    GAME_PATH="$game_path"

    local file_count
    file_count=$(find "$GAME_PATH" -maxdepth 1 -type f | head -5 | wc -l)
    if [ "$file_count" -eq 0 ]; then
        echo "Warning: '$GAME_PATH' appears to be empty."
        read -rp "Continue anyway? [y/N]: " confirm
        if [ "${confirm,,}" != "y" ]; then
            exit 1
        fi
    fi
    echo ""
}

ask_port() {
    read -rp "Port to serve on (default: $DEFAULT_PORT): " port
    port="${port:-$DEFAULT_PORT}"

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "Error: Port must be a number."
        exit 1
    fi
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "Error: Port must be between 1 and 65535."
        exit 1
    fi

    PORT="$port"
    echo ""
}

generate_override() {
    cat > docker-compose.override.yml <<YAML
services:
  umineko-web:
    ports:
      - "${PORT}:80"
    volumes:
      - "${GAME_PATH}:/usr/share/nginx/html/game:ro"
      - asset-cache:/usr/share/nginx/html/cache
    environment:
      - HOSTING_MODE=${HOSTING_MODE}
YAML
    echo "Generated docker-compose.override.yml"
}

run_docker() {
    echo ""
    docker compose down 2>/dev/null || true
    echo "Building and starting containers..."
    echo ""
    docker compose build --build-arg "ONS_CACHE_BUST=$(date +%s)"
    docker compose up -d
}

print_success() {
    echo ""
    echo "=========================================="
    echo "  Umineko Web is running!"
    echo "=========================================="
    echo ""
    echo "  URL:  http://localhost:${PORT}"
    echo "  Mode: ${HOSTING_MODE}"
    echo "  Game: ${GAME_PATH}"
    echo ""
    if [ "$HOSTING_MODE" = "production" ]; then
        echo "  Asset conversion is running in the background."
        echo "  Check progress: docker compose logs -f"
        echo ""
    fi
    echo "  Stop:    docker compose down"
    echo "  Restart: docker compose up -d"
    echo "  Re-run:  ./setup/setup.sh"
    echo ""
}

print_banner
check_docker
check_existing
ask_hosting_mode
ask_game_path
ask_port
generate_override
run_docker
print_success
