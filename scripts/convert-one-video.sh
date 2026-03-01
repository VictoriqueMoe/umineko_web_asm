#!/bin/sh
src="$1"
rel="${src#$SRC_DIR/}"
dst="$CACHE_DIR/${rel%.mp4}.webm"
if [ -f "$dst" ] && [ "$dst" -nt "$src" ]; then
    exit 0
fi
tmp="$dst.tmp"
errlog="/tmp/ffmpeg_vid_$$.log"
mkdir -p "$(dirname "$dst")"
if ffmpeg -y -i "$src" \
    -c:v libvpx-vp9 -crf "$VP9_CRF" -b:v 0 \
    -c:a libopus -b:a 128k \
    -f webm "$tmp" 2>"$errlog"; then
    mv "$tmp" "$dst"
    printf "." >> "$PROGRESS_FILE"
    count=$(wc -c < "$PROGRESS_FILE")
    pct=$((count * 100 / VID_COUNT))
    echo "[$(date +%H:%M:%S)] [convert] Videos: $count/$VID_COUNT ($pct%) converted ($rel)"
else
    echo "[$(date +%H:%M:%S)] [convert] FAILED: $rel ($(tail -1 "$errlog"))"
    rm -f "$tmp" "$errlog"
fi
