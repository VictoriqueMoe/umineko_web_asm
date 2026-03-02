$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectRoot

$DEFAULT_GAME_PATH = ".\game"
$DEFAULT_PORT = "8080"

function Print-Banner {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  Umineko Web - Setup"
    Write-Host "=========================================="
    Write-Host ""
}

function Check-Docker {
    try {
        $null = Get-Command docker -ErrorAction Stop
    }
    catch {
        Write-Host "Error: Docker is not installed."
        Write-Host "Install it from https://docs.docker.com/get-docker/"
        exit 1
    }
    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Docker is not running. Please start Docker Desktop and try again."
        exit 1
    }
    $null = docker compose version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Docker Compose is not available."
        Write-Host "It should be included with Docker Desktop."
        exit 1
    }
}

function Check-Existing {
    if (Test-Path "docker-compose.override.yml") {
        Write-Host "Existing installation detected."
        Write-Host ""
        Write-Host "  1) Update    - Pull latest changes and rebuild"
        Write-Host "  2) Configure - Re-run setup with new settings"
        Write-Host ""
        while ($true) {
            $choice = Read-Host "Choose [1/2] (default: 1)"
            if ([string]::IsNullOrWhiteSpace($choice)) {
                $choice = "1"
            }
            if ($choice -eq "1") {
                Do-Update
                exit 0
            }
            elseif ($choice -eq "2") {
                return
            }
            else {
                Write-Host "Please enter 1 or 2."
            }
        }
    }
}

function Do-Update {
    Write-Host ""
    Write-Host "Pulling latest changes..."
    git pull
    Write-Host ""
    docker compose down 2>$null
    Write-Host "Rebuilding..."
    Write-Host ""
    $cacheBust = [int][double]::Parse((Get-Date -UFormat %s))
    docker compose build --build-arg "ONS_CACHE_BUST=$cacheBust"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Docker build failed."
        exit 1
    }
    docker compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to start containers."
        exit 1
    }

    $port = "8080"
    $overrideContent = Get-Content "docker-compose.override.yml" -Raw -ErrorAction SilentlyContinue
    if ($overrideContent -match '"(\d+):80"') {
        $port = $Matches[1]
    }

    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  Umineko Web updated!"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "  URL: http://localhost:${port}"
    Write-Host ""
}

function Ask-HostingMode {
    Write-Host "How do you want to run Umineko Web?"
    Write-Host ""
    Write-Host "  1) Local      - Serves original game files directly (fast startup)"
    Write-Host "  2) Production - Converts assets for smaller file sizes (PNG->WebP,"
    Write-Host "                  MP4->WebM, OGG re-encoding). Takes a while on first run."
    Write-Host ""
    while ($true) {
        $choice = Read-Host "Choose [1/2] (default: 1)"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = "1"
        }
        if ($choice -eq "1") {
            $script:HOSTING_MODE = "local"
            break
        }
        elseif ($choice -eq "2") {
            $script:HOSTING_MODE = "production"
            break
        }
        else {
            Write-Host "Please enter 1 or 2."
        }
    }
    Write-Host ""
}

function Ask-GamePath {
    Write-Host "Where are your Umineko game files?"
    $gamePath = Read-Host "Path (default: $DEFAULT_GAME_PATH)"
    if ([string]::IsNullOrWhiteSpace($gamePath)) {
        $gamePath = $DEFAULT_GAME_PATH
    }

    $resolved = Resolve-Path -Path $gamePath -ErrorAction SilentlyContinue
    if (-not $resolved) {
        Write-Host "Error: Directory '$gamePath' does not exist."
        exit 1
    }

    $script:GAME_PATH = $resolved.Path

    if (-not (Test-Path $script:GAME_PATH -PathType Container)) {
        Write-Host "Error: '$($script:GAME_PATH)' is not a directory."
        exit 1
    }

    $fileCount = (Get-ChildItem -Path $script:GAME_PATH -File -ErrorAction SilentlyContinue | Select-Object -First 5).Count
    if ($fileCount -eq 0) {
        Write-Host "Warning: '$($script:GAME_PATH)' appears to be empty."
        $confirm = Read-Host "Continue anyway? [y/N]"
        if ($confirm -ne "y") {
            exit 1
        }
    }
    Write-Host ""
}

function Ask-Port {
    $port = Read-Host "Port to serve on (default: $DEFAULT_PORT)"
    if ([string]::IsNullOrWhiteSpace($port)) {
        $port = $DEFAULT_PORT
    }

    if ($port -notmatch '^\d+$') {
        Write-Host "Error: Port must be a number."
        exit 1
    }
    $portNum = [int]$port
    if ($portNum -lt 1 -or $portNum -gt 65535) {
        Write-Host "Error: Port must be between 1 and 65535."
        exit 1
    }

    $script:PORT = $port
    Write-Host ""
}

function Generate-Override {
    $gamePath = $script:GAME_PATH -replace '\\', '/'
    $yaml = @"
services:
  umineko-web:
    ports:
      - "$($script:PORT):80"
    volumes:
      - "${gamePath}:/usr/share/nginx/html/game:ro"
      - asset-cache:/usr/share/nginx/html/cache
    environment:
      - HOSTING_MODE=$($script:HOSTING_MODE)
"@
    $yaml | Set-Content -Path "docker-compose.override.yml" -Encoding UTF8
    Write-Host "Generated docker-compose.override.yml"
}

function Run-Docker {
    Write-Host ""
    docker compose down 2>$null
    Write-Host "Building and starting containers..."
    Write-Host ""
    $cacheBust = [int][double]::Parse((Get-Date -UFormat %s))
    docker compose build --build-arg "ONS_CACHE_BUST=$cacheBust"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Docker build failed."
        exit 1
    }
    docker compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to start containers."
        exit 1
    }
}

function Print-Success {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  Umineko Web is running!"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "  URL:  http://localhost:$($script:PORT)"
    Write-Host "  Mode: $($script:HOSTING_MODE)"
    Write-Host "  Game: $($script:GAME_PATH)"
    Write-Host ""
    if ($script:HOSTING_MODE -eq "production") {
        Write-Host "  Asset conversion is running in the background."
        Write-Host "  Check progress: docker compose logs -f"
        Write-Host ""
    }
    Write-Host "  Stop:    docker compose down"
    Write-Host "  Restart: docker compose up -d"
    Write-Host "  Re-run:  .\setup\setup.ps1"
    Write-Host ""
}

Print-Banner
Check-Docker
Check-Existing
Ask-HostingMode
Ask-GamePath
Ask-Port
Generate-Override
Run-Docker
Print-Success
