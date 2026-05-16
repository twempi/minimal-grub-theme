#!/usr/bin/env bash
set -euo pipefail

DEFAULT_FONT_SIZE="28"
DEFAULT_FONT_RANGE="0x20-0x7e,0xa0-0xff,0x2010-0x2026"
DEFAULT_FONT_NAME="custom"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

font_size="$DEFAULT_FONT_SIZE"
font_range="$DEFAULT_FONT_RANGE"
font_name="$DEFAULT_FONT_NAME"
source_font="$REPO_DIR/minimal/original.ttf"
output="$REPO_DIR/minimal/custom.pf2"

usage() {
    cat <<USAGE
Usage:
  scripts/build-font.sh [options]

Options:
  --font-size POINTS  Generated GRUB font size. Default: $DEFAULT_FONT_SIZE.
  --font-range RANGE  grub-mkfont range. Default: $DEFAULT_FONT_RANGE.
  --name NAME         Internal GRUB font name. Default: $DEFAULT_FONT_NAME.
  --source-font PATH  Source TTF/OTF font. Default: minimal/original.ttf.
  --output PATH       Output PF2 path. Default: minimal/custom.pf2.
  -h, --help          Show this help.
USAGE
}

die() {
    printf 'build-font.sh: %s\n' "$*" >&2
    exit 1
}

need_value() {
    local opt="$1"
    local value="${2-}"

    [[ -n "$value" ]] || die "$opt requires a value"
}

is_positive_int() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

find_grub_mkfont() {
    if [[ -n "${GRUB_MKFONT:-}" ]]; then
        command -v "$GRUB_MKFONT"
    elif command -v grub-mkfont >/dev/null 2>&1; then
        command -v grub-mkfont
    elif command -v grub2-mkfont >/dev/null 2>&1; then
        command -v grub2-mkfont
    else
        return 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --font-size)
            need_value "$1" "${2-}"
            font_size="$2"
            shift 2
            ;;
        --font-size=*)
            font_size="${1#*=}"
            shift
            ;;
        --font-range)
            need_value "$1" "${2-}"
            font_range="$2"
            shift 2
            ;;
        --font-range=*)
            font_range="${1#*=}"
            shift
            ;;
        --name)
            need_value "$1" "${2-}"
            font_name="$2"
            shift 2
            ;;
        --name=*)
            font_name="${1#*=}"
            shift
            ;;
        --source-font)
            need_value "$1" "${2-}"
            source_font="$2"
            shift 2
            ;;
        --source-font=*)
            source_font="${1#*=}"
            shift
            ;;
        --output)
            need_value "$1" "${2-}"
            output="$2"
            shift 2
            ;;
        --output=*)
            output="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

is_positive_int "$font_size" || die "--font-size must be a positive integer"
[[ -n "$font_range" ]] || die "--font-range cannot be empty"
[[ -n "$font_name" ]] || die "--name cannot be empty"
[[ -f "$source_font" ]] || die "source font not found: $source_font"
[[ -n "$output" ]] || die "--output cannot be empty"

grub_mkfont="$(find_grub_mkfont)" || die "could not find grub-mkfont or grub2-mkfont"

install -d -- "$(dirname -- "$output")"
"$grub_mkfont" \
    -s "$font_size" \
    -n "$font_name" \
    -r "$font_range" \
    -o "$output" \
    "$source_font"

printf 'Generated %s\n' "$output"
