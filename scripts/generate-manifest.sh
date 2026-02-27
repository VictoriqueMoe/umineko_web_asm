#!/bin/sh
GAME_DIR="/usr/share/nginx/html/game"
MANIFEST="/usr/share/nginx/html/manifest.json"

if [ ! -d "$GAME_DIR" ]; then
    echo '{"dirs":[],"files":[]}' > "$MANIFEST"
    exit 0
fi

echo "Generating asset manifest..."

if command -v jq >/dev/null 2>&1; then
  DIRS="$(find "$GAME_DIR" -mindepth 1 -type d -printf '%P\0' | sort -z | jq -Rsc 'split("\u0000")[:-1]')"
  FILES="$(find "$GAME_DIR" -mindepth 1 -type f -printf '%P\0' | sort -z | jq -Rsc 'split("\u0000")[:-1]')"
  jq -cn --argjson dirs "$DIRS" --argjson files "$FILES" '{dirs:$dirs,files:$files}' > "$MANIFEST"
  echo "Manifest generated: $(jq -r 'length' <<<"$FILES") files in $(jq -r 'length' <<<"$DIRS") directories"
  exit 0
fi

printf '{"dirs":[' > "$MANIFEST"
find "$GAME_DIR" -type d | sed "s|$GAME_DIR/||" | grep -v '^$' | sort | awk '
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
find "$GAME_DIR" -type f | sed "s|$GAME_DIR/||" | sort | awk '
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
