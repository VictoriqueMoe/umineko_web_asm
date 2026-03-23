#!/usr/bin/env bash
set -euo pipefail

GAME_DIR="${1:?Usage: $0 <game-dir> <classic-arc-dir> <output-dir>}"
CLASSIC_ARC_DIR="${2:?Usage: $0 <game-dir> <classic-arc-dir> <output-dir>}"
OUTPUT_DIR="${3:?Usage: $0 <game-dir> <classic-arc-dir> <output-dir>}"

CLASSIC_SEARCH_PATHS=(
    "$CLASSIC_ARC_DIR/Umineko Answers/arc~.nsa/bmp/tati"
    "$CLASSIC_ARC_DIR/Umineko Questions/arc~.nsa/bmp/tati"
)

if command -v magick &>/dev/null; then
    MAGICK_CMD="magick"
elif command -v convert &>/dev/null; then
    MAGICK_CMD="convert"
else
    echo "Error: ImageMagick is required but not found."
    echo "Install it:"
    echo "  macOS:  brew install imagemagick"
    echo "  Ubuntu: sudo apt install imagemagick"
    echo "  Windows: https://imagemagick.org/script/download.php"
    exit 1
fi

valid_search_paths=()
for p in "${CLASSIC_SEARCH_PATHS[@]}"; do
    if [[ -d "$p" ]]; then
        valid_search_paths+=("$p")
    fi
done

if [[ ${#valid_search_paths[@]} -eq 0 ]]; then
    echo "Error: No classic sprite directories found in '$CLASSIC_ARC_DIR'."
    echo "Expected structure:"
    echo "  $CLASSIC_ARC_DIR/Umineko Questions/arc~.nsa/bmp/tati/"
    echo "  $CLASSIC_ARC_DIR/Umineko Answers/arc~.nsa/bmp/tati/"
    exit 1
fi

find_classic_sprite() {
    local char="$1"
    local expr="$2"
    for base in "${valid_search_paths[@]}"; do
        for subdir in 1 2 3; do
            local candidate="$base/$char/$subdir/${char}_${expr}.png"
            if [[ -f "$candidate" ]]; then
                echo "$candidate"
                return 0
            fi
        done
    done
    return 1
}

strip_outfit_prefix() {
    local expr="$1"
    echo "$expr" | sed -E 's/^[a-z]{1,2}[0-9]+[a-z]*_([0-9]+_)?//'
}

map_expression() {
    local stripped="$1"
    local char="$2"

    if [[ -z "$stripped" ]]; then
        return 1
    fi

    local base num_suffix
    base=$(echo "$stripped" | sed -E 's/[0-9]+[a-z]*$//')
    num_suffix="${stripped#$base}"

    if [[ "$base" == "$stripped" ]]; then
        return 1
    fi

    if [[ "$base" == "defo" ]]; then
        base="def"
    fi

    local candidate="${base}a${num_suffix}"
    if find_classic_sprite "$char" "$candidate" &>/dev/null; then
        echo "$candidate"
        return 0
    fi

    candidate="${base}b${num_suffix}"
    if find_classic_sprite "$char" "$candidate" &>/dev/null; then
        echo "$candidate"
        return 0
    fi

    if find_classic_sprite "$char" "$stripped" &>/dev/null; then
        echo "$stripped"
        return 0
    fi

    candidate="${base}a1"
    if find_classic_sprite "$char" "$candidate" &>/dev/null; then
        echo "$candidate"
        return 0
    fi

    return 1
}

get_png_dimensions() {
    local file="$1"
    local header
    header=$(xxd -l 24 -p "$file" 2>/dev/null)
    if [[ ${#header} -ge 48 ]]; then
        local w_hex="${header:32:8}"
        local h_hex="${header:40:8}"
        local w=$((16#$w_hex))
        local h=$((16#$h_hex))
        echo "${w}x${h}"
        return 0
    fi
    return 1
}

echo ""
echo "Setting up classic sprites..."
echo ""

PS3_SPRITES_DIR="$GAME_DIR/sprites"
if [[ ! -d "$PS3_SPRITES_DIR" ]]; then
    echo "Error: No sprites directory found at '$PS3_SPRITES_DIR'"
    exit 1
fi

TOTAL=0
PROCESSED=0
SKIPPED=0
FAILED=0

for char_dir in "$PS3_SPRITES_DIR"/*/; do
    char=$(basename "$char_dir")
    layer1="$char_dir/1"

    if [[ ! -d "$layer1" ]]; then
        continue
    fi

    char_mapped=0
    char_total=0

    for ps3_file in "$layer1"/*.png; do
        [[ -f "$ps3_file" ]] || continue
        filename=$(basename "$ps3_file")
        prefix="${char}_"

        if [[ ! "$filename" == ${prefix}* ]]; then
            continue
        fi

        ps3_expr="${filename#$prefix}"
        ps3_expr="${ps3_expr%.png}"
        TOTAL=$((TOTAL + 1))
        char_total=$((char_total + 1))

        out_file="$OUTPUT_DIR/sprites/$char/1/$filename"
        if [[ -f "$out_file" ]]; then
            SKIPPED=$((SKIPPED + 1))
            char_mapped=$((char_mapped + 1))
            continue
        fi

        stripped=$(strip_outfit_prefix "$ps3_expr")
        if [[ -z "$stripped" || "$stripped" == "$ps3_expr" ]]; then
            FAILED=$((FAILED + 1))
            continue
        fi

        classic_expr=$(map_expression "$stripped" "$char" 2>/dev/null || true)
        if [[ -z "$classic_expr" ]]; then
            FAILED=$((FAILED + 1))
            continue
        fi

        classic_file=$(find_classic_sprite "$char" "$classic_expr" 2>/dev/null || true)
        if [[ -z "$classic_file" ]]; then
            FAILED=$((FAILED + 1))
            continue
        fi

        dims=$(get_png_dimensions "$ps3_file" 2>/dev/null || true)
        if [[ -z "$dims" ]]; then
            FAILED=$((FAILED + 1))
            continue
        fi

        ps3_w="${dims%x*}"
        ps3_h="${dims#*x}"

        if [[ "$ps3_w" -eq 0 || "$ps3_h" -eq 0 ]]; then
            FAILED=$((FAILED + 1))
            continue
        fi

        mkdir -p "$OUTPUT_DIR/sprites/$char/1"

        $MAGICK_CMD "$classic_file" \
            -trim +repage \
            -resize "${ps3_w}x${ps3_h}" \
            -background none \
            -gravity south \
            -extent "${ps3_w}x${ps3_h}" \
            "$out_file" 2>/dev/null

        PROCESSED=$((PROCESSED + 1))
        char_mapped=$((char_mapped + 1))

        if (( PROCESSED % 100 == 0 )); then
            echo "  Processed $PROCESSED sprites..."
        fi
    done

    if [[ $char_total -gt 0 ]]; then
        echo "  [$char] $char_mapped/$char_total mapped"
    fi
done

echo ""
echo "=========================================="
echo "  Classic sprites setup complete!"
echo "=========================================="
echo ""
echo "  Total PS3 sprites:   $TOTAL"
echo "  Mapped to classic:   $((PROCESSED + SKIPPED))"
echo "  Newly processed:     $PROCESSED"
echo "  Already existed:     $SKIPPED"
echo "  No classic match:    $FAILED"
echo "  Output:              $OUTPUT_DIR/sprites/"
echo ""
