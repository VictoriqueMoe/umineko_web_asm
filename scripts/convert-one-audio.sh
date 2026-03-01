#!/bin/sh
src="$1"
rel="${src#$SRC_DIR/}"
dst="$CACHE_DIR/$rel"
if [ -f "$dst" ] && [ "$dst" -nt "$src" ]; then
    exit 0
fi
tmp="$dst.tmp"
mkdir -p "$(dirname "$dst")"
if ffmpeg -y -i "$src" -c:a libvorbis -q:a "$OGG_QUALITY" -f ogg "$tmp" > /dev/null 2>&1; then
    src_size=$(wc -c < "$src")
    dst_size=$(wc -c < "$tmp")
    if [ "$dst_size" -ge "$src_size" ]; then
        rm -f "$tmp"
        exit 0
    fi
    mv "$tmp" "$dst"
    printf "." >> "$PROGRESS_FILE"
    count=$(wc -c < "$PROGRESS_FILE")
    if [ $((count % 50)) -eq 0 ]; then
        pct=$((count * 100 / OGG_COUNT))
        echo "[$(date +%H:%M:%S)] [convert] Audio: $count/$OGG_COUNT ($pct%) re-encoded"
    fi
else
    rm -f "$tmp"
fi
