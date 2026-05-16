#!/usr/bin/env bash
set -euo pipefail

THEME_NAME="minimal"
DEFAULT_TIMEOUT="5"
DEFAULT_FONT_SIZE="28"
DEFAULT_FONT_RANGE="0x20-0x7e,0xa0-0xff,0x2010-0x2026"
BEGIN_MARKER="# BEGIN minimal-grub-theme"
END_MARKER="# END minimal-grub-theme"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_FONT="$SCRIPT_DIR/scripts/build-font.sh"

apply=0
dry_run=0
theme_dir=""
timeout="$DEFAULT_TIMEOUT"
font_size="$DEFAULT_FONT_SIZE"
font_range="$DEFAULT_FONT_RANGE"
mkconfig_mode="auto"

usage() {
    cat <<USAGE
Usage:
  ./Install.sh [--dry-run] [--timeout SECONDS] [--font-size POINTS]
  sudo ./Install.sh --apply [options]

Options:
  --apply               Install files, write managed GRUB config, and run mkconfig.
  --dry-run             Print planned actions without writing anything.
  --theme-dir PATH      Theme install directory. Defaults to /boot/grub*/themes/minimal.
  --timeout SECONDS     Automatic boot timeout. Default: $DEFAULT_TIMEOUT.
  --font-size POINTS    Generated GRUB font size. Default: $DEFAULT_FONT_SIZE.
  --font-range RANGE    grub-mkfont range. Default: $DEFAULT_FONT_RANGE.
  --mkconfig VALUE      auto, never, or a full command to run. Default: auto.
  -h, --help            Show this help.
USAGE
}

die() {
    printf 'Install.sh: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '%s\n' "$*"
}

is_uint() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

is_positive_int() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

need_value() {
    local opt="$1"
    local value="${2-}"

    [[ -n "$value" ]] || die "$opt requires a value"
}

detect_theme_dir() {
    if [[ -d /boot/grub ]]; then
        printf '/boot/grub/themes/%s\n' "$THEME_NAME"
    elif [[ -d /boot/grub2 ]]; then
        printf '/boot/grub2/themes/%s\n' "$THEME_NAME"
    elif [[ "$apply" -eq 1 ]]; then
        die "could not find /boot/grub or /boot/grub2; pass --theme-dir"
    else
        printf '/boot/grub/themes/%s\n' "$THEME_NAME"
    fi
}

find_mkconfig_command() {
    if command -v grub2-mkconfig >/dev/null 2>&1; then
        command -v grub2-mkconfig
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        command -v grub-mkconfig
    elif command -v update-grub >/dev/null 2>&1; then
        command -v update-grub
    else
        return 1
    fi
}

detect_grub_cfg() {
    case "$theme_dir" in
        /boot/grub2/*) printf '/boot/grub2/grub.cfg\n' ;;
        *) printf '/boot/grub/grub.cfg\n' ;;
    esac
}

backup_file() {
    local file="$1"
    local backup

    [[ -e "$file" ]] || return 0
    backup="${file}.bak.$(date +%Y%m%d-%H%M%S)"
    cp -a -- "$file" "$backup"
    log "Backed up $file to $backup"
}

guard_theme_dir() {
    local path="$1"

    [[ -n "$path" ]] || die "theme directory is empty"
    case "$path" in
        /|/boot|/boot/|/boot/grub|/boot/grub/|/boot/grub2|/boot/grub2/|/boot/grub/themes|/boot/grub/themes/|/boot/grub2/themes|/boot/grub2/themes/|/etc|/usr|/usr/share)
            die "refusing to replace unsafe theme directory: $path"
            ;;
    esac
}

write_config_values() {
    cat <<CONFIG
GRUB_THEME="$theme_dir/theme.txt"
GRUB_TIMEOUT=$timeout
GRUB_TIMEOUT_STYLE=menu
CONFIG
}

remove_managed_block() {
    local file="$1"

    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
    ' "$file"
}

write_grub_config() {
    local grub_default="/etc/default/grub"
    local dropin_dir="/etc/default/grub.d"
    local dropin_file="$dropin_dir/${THEME_NAME}-theme.cfg"
    local tmp

    if [[ -d "$dropin_dir" ]]; then
        backup_file "$dropin_file"
        tmp="$(mktemp)"
        {
            printf '# Managed by minimal-grub-theme. Remove with Uninstall.sh --apply.\n'
            write_config_values
        } >"$tmp"
        install -m 0644 -- "$tmp" "$dropin_file"
        rm -f -- "$tmp"
        log "Wrote managed GRUB config snippet: $dropin_file"
        return 0
    fi

    [[ -f "$grub_default" ]] || die "$grub_default does not exist; cannot write GRUB settings"

    backup_file "$grub_default"
    tmp="$(mktemp)"
    remove_managed_block "$grub_default" >"$tmp"
    {
        printf '\n%s\n' "$BEGIN_MARKER"
        write_config_values
        printf '%s\n' "$END_MARKER"
    } >>"$tmp"
    install -m 0644 -- "$tmp" "$grub_default"
    rm -f -- "$tmp"
    log "Updated managed block in $grub_default"
}

run_mkconfig() {
    local command_path
    local grub_cfg

    if [[ "$mkconfig_mode" == "never" ]]; then
        log "Skipped GRUB config regeneration because --mkconfig never was set."
        return 0
    fi

    if [[ "$mkconfig_mode" == "auto" ]]; then
        command_path="$(find_mkconfig_command)" || die "could not find grub2-mkconfig, grub-mkconfig, or update-grub"
        case "$(basename -- "$command_path")" in
            update-grub)
                log "Running $command_path"
                "$command_path"
                ;;
            *)
                grub_cfg="$(detect_grub_cfg)"
                log "Running $command_path -o $grub_cfg"
                "$command_path" -o "$grub_cfg"
                ;;
        esac
    else
        log "Running custom mkconfig command: $mkconfig_mode"
        sh -c "$mkconfig_mode"
    fi
}

print_plan() {
    cat <<PLAN
Install plan:
  theme directory: $theme_dir
  generated font size: $font_size
  generated font range: $font_range
  timeout: $timeout
  mkconfig: $mkconfig_mode

Managed GRUB settings:
  GRUB_THEME="$theme_dir/theme.txt"
  GRUB_TIMEOUT=$timeout
  GRUB_TIMEOUT_STYLE=menu
PLAN

    if [[ "$apply" -eq 0 ]]; then
        cat <<'PLAN'

No changes were made. Re-run with --apply under sudo to install and write GRUB config.
PLAN
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply)
            apply=1
            shift
            ;;
        --dry-run)
            dry_run=1
            shift
            ;;
        --theme-dir)
            need_value "$1" "${2-}"
            theme_dir="$2"
            shift 2
            ;;
        --theme-dir=*)
            theme_dir="${1#*=}"
            shift
            ;;
        --timeout)
            need_value "$1" "${2-}"
            timeout="$2"
            shift 2
            ;;
        --timeout=*)
            timeout="${1#*=}"
            shift
            ;;
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
        --mkconfig)
            need_value "$1" "${2-}"
            mkconfig_mode="$2"
            shift 2
            ;;
        --mkconfig=*)
            mkconfig_mode="${1#*=}"
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

[[ "$apply" -eq 0 || "$dry_run" -eq 0 ]] || die "--apply and --dry-run cannot be used together"
is_uint "$timeout" || die "--timeout must be a non-negative integer"
is_positive_int "$font_size" || die "--font-size must be a positive integer"
[[ -n "$font_range" ]] || die "--font-range cannot be empty"

if [[ -z "$theme_dir" ]]; then
    theme_dir="$(detect_theme_dir)"
fi

case "$theme_dir" in
    /*) ;;
    *) die "--theme-dir must be an absolute path" ;;
esac

if [[ "$dry_run" -eq 1 || "$apply" -eq 0 ]]; then
    print_plan
    exit 0
fi

[[ "$EUID" -eq 0 ]] || die "root privileges needed. Run with sudo or use --dry-run."
[[ -x "$BUILD_FONT" ]] || die "missing executable font builder: $BUILD_FONT"

if [[ "$mkconfig_mode" == "auto" ]]; then
    find_mkconfig_command >/dev/null || die "could not find grub2-mkconfig, grub-mkconfig, or update-grub; use --mkconfig never to skip"
fi

guard_theme_dir "$theme_dir"

stage="$(mktemp -d)"
tmp_dest=""
cleanup() {
    rm -rf -- "$stage"
    if [[ -n "$tmp_dest" ]]; then
        rm -rf -- "$tmp_dest"
    fi
}
trap cleanup EXIT

print_plan

install -d -- "$stage/$THEME_NAME"
install -m 0644 -- "$SCRIPT_DIR/minimal/theme.txt" "$stage/$THEME_NAME/theme.txt"
"$BUILD_FONT" \
    --font-size "$font_size" \
    --font-range "$font_range" \
    --output "$stage/$THEME_NAME/custom.pf2" \
    --source-font "$SCRIPT_DIR/minimal/original.ttf"

install -d -- "$(dirname -- "$theme_dir")"
tmp_dest="$(dirname -- "$theme_dir")/.${THEME_NAME}.install.$$"
rm -rf -- "$tmp_dest"
install -d -- "$tmp_dest"
install -m 0644 -- "$stage/$THEME_NAME/theme.txt" "$tmp_dest/theme.txt"
install -m 0644 -- "$stage/$THEME_NAME/custom.pf2" "$tmp_dest/custom.pf2"
rm -rf -- "$theme_dir"
mv -- "$tmp_dest" "$theme_dir"
tmp_dest=""
log "Installed theme files to $theme_dir"

write_grub_config
run_mkconfig

log "minimal GRUB theme installed."
