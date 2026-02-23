#!/bin/sh
GAME_DIR="/usr/share/nginx/html/game"
MANIFEST="/usr/share/nginx/html/manifest.json"

if [ ! -d "$GAME_DIR" ]; then
    echo '{"dirs":[],"files":[]}' > "$MANIFEST"
    exit 0
fi

echo "Generating asset manifest..."

printf '{"dirs":[' > "$MANIFEST"
find "$GAME_DIR" -type d | sed "s|$GAME_DIR||" | grep -v '^$' | sort | awk '
    BEGIN { first = 1 }
    {
        gsub(/\\/, "\\\\")
        gsub(/"/, "\\\"")
        if (!first) printf ","
        printf "\"%s\"", $0
        first = 0
    }
' >> "$MANIFEST"

printf '],"files":[' >> "$MANIFEST"
find "$GAME_DIR" -type f | sed "s|$GAME_DIR||" | sort | awk '
    BEGIN { first = 1 }
    {
        gsub(/\\/, "\\\\")
        gsub(/"/, "\\\"")
        if (!first) printf ","
        printf "\"%s\"", $0
        first = 0
    }
' >> "$MANIFEST"

printf ']}' >> "$MANIFEST"

COUNT=$(find "$GAME_DIR" -type f | wc -l)
echo "Manifest generated: $COUNT files"
