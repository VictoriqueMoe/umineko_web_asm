#!/bin/sh
src="$1"
rel="${src#$SRC_DIR/}"
dst="$CACHE_DIR/${rel%.png}.webp"
if [ -f "$dst" ] && [ "$dst" -nt "$src" ]; then
    exit 0
fi
tmp="$dst.tmp"
mkdir -p "$(dirname "$dst")"
if cwebp -q "$WEBP_QUALITY" "$src" -o "$tmp" > /dev/null 2>&1; then
    mv "$tmp" "$dst"
    printf "." >> "$PROGRESS_FILE"
    count=$(wc -c < "$PROGRESS_FILE")
    if [ $((count % 100)) -eq 0 ]; then
        pct=$((count * 100 / IMG_COUNT))
        echo "[$(date +%H:%M:%S)] [convert] Images: $count/$IMG_COUNT ($pct%) converted"
    fi
else
    rm -f "$tmp"
fi
