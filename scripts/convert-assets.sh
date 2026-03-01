#!/bin/sh

SRC_DIR="${1:?Usage: convert-assets.sh <source-dir> <cache-dir>}"
CACHE_DIR="${2:?Usage: convert-assets.sh <source-dir> <cache-dir>}"
LOG="/tmp/convert.log"
WEBP_QUALITY=90
VP9_CRF=30
PARALLEL=8
PROGRESS_FILE="/tmp/convert_progress"

echo "" > "$LOG"
log() {
    msg="[$(date '+%H:%M:%S')] [convert] $1"
    echo "$msg" >> "$LOG"
    echo "$msg"
}

log "Starting asset conversion"
log "Source: $SRC_DIR"
log "Cache: $CACHE_DIR"

mkdir -p "$CACHE_DIR"

find "$CACHE_DIR" -name "*.tmp" -delete 2>/dev/null

IMG_COUNT=$(find "$SRC_DIR" -type f -name "*.png" | wc -l)
VID_COUNT=$(find "$SRC_DIR" -type f -name "*.mp4" | wc -l)
OGG_MIN_SIZE=1048576
OGG_COUNT=$(find "$SRC_DIR" -type f -name "*.ogg" -size +${OGG_MIN_SIZE}c | wc -l)
OGG_QUALITY=4
export SRC_DIR CACHE_DIR WEBP_QUALITY VP9_CRF OGG_QUALITY PROGRESS_FILE IMG_COUNT VID_COUNT OGG_COUNT

log "Found $IMG_COUNT PNG images, $VID_COUNT MP4 videos, $OGG_COUNT OGG audio (>1MB)"

log "Converting images (PNG -> WebP) with $PARALLEL parallel workers..."
: > "$PROGRESS_FILE"
find "$SRC_DIR" -type f -name "*.png" -print0 | xargs -0 -P "$PARALLEL" -n 1 /usr/local/bin/convert-one-image.sh

FINAL_IMG=$(wc -c < "$PROGRESS_FILE")
log "Images done: $FINAL_IMG converted"

log "Converting videos (MP4 -> WebM/VP9)..."
: > "$PROGRESS_FILE"
find "$SRC_DIR" -type f -name "*.mp4" -print0 | xargs -0 -P 4 -n 1 /usr/local/bin/convert-one-video.sh

FINAL_VID=$(wc -c < "$PROGRESS_FILE")
log "Videos done: $FINAL_VID converted"

log "Re-encoding large OGG audio (>1MB) at quality $OGG_QUALITY..."
: > "$PROGRESS_FILE"
find "$SRC_DIR" -type f -name "*.ogg" -size +${OGG_MIN_SIZE}c -print0 | xargs -0 -P "$PARALLEL" -n 1 /usr/local/bin/convert-one-audio.sh

FINAL_OGG=$(wc -c < "$PROGRESS_FILE")
log "Audio done: $FINAL_OGG re-encoded"
log "Conversion complete"
