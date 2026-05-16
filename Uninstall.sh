#!/usr/bin/env bash
set -euo pipefail

THEME_NAME="minimal"
BEGIN_MARKER="# BEGIN minimal-grub-theme"
END_MARKER="# END minimal-grub-theme"

apply=0
dry_run=0
theme_dir=""
mkconfig_mode="auto"
changed=0

usage() {
    cat <<USAGE
Usage:
  ./Uninstall.sh [--dry-run]
  sudo ./Uninstall.sh --apply [options]

Options:
  --apply           Remove managed theme files/config and run mkconfig.
  --dry-run         Print planned actions without writing anything.
  --theme-dir PATH  Theme install directory. Defaults to /boot/grub*/themes/minimal.
  --mkconfig VALUE  auto, never, or a full command to run. Default: auto.
  -h, --help        Show this help.
USAGE
}

die() {
    printf 'Uninstall.sh: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '%s\n' "$*"
}

need_value() {
    local opt="$1"
    local value="${2-}"

    [[ -n "$value" ]] || die "$opt requires a value"
}

detect_theme_dir() {
    if [[ -d /boot/grub/themes/$THEME_NAME ]]; then
        printf '/boot/grub/themes/%s\n' "$THEME_NAME"
    elif [[ -d /boot/grub2/themes/$THEME_NAME ]]; then
        printf '/boot/grub2/themes/%s\n' "$THEME_NAME"
    elif [[ -d /boot/grub ]]; then
        printf '/boot/grub/themes/%s\n' "$THEME_NAME"
    elif [[ -d /boot/grub2 ]]; then
        printf '/boot/grub2/themes/%s\n' "$THEME_NAME"
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
            die "refusing to remove unsafe theme directory: $path"
            ;;
    esac
}

remove_managed_block() {
    local file="$1"

    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
    ' "$file"
}

remove_theme_dir() {
    guard_theme_dir "$theme_dir"

    if [[ -d "$theme_dir" ]]; then
        rm -rf -- "$theme_dir"
        changed=1
        log "Removed theme directory: $theme_dir"
    else
        log "Theme directory not present: $theme_dir"
    fi
}

remove_grub_config() {
    local grub_default="/etc/default/grub"
    local dropin_file="/etc/default/grub.d/${THEME_NAME}-theme.cfg"
    local tmp

    if [[ -f "$dropin_file" ]]; then
        backup_file "$dropin_file"
        rm -f -- "$dropin_file"
        changed=1
        log "Removed managed GRUB config snippet: $dropin_file"
    fi

    if [[ -f "$grub_default" ]] && grep -Fxq "$BEGIN_MARKER" "$grub_default"; then
        backup_file "$grub_default"
        tmp="$(mktemp)"
        remove_managed_block "$grub_default" >"$tmp"
        install -m 0644 -- "$tmp" "$grub_default"
        rm -f -- "$tmp"
        changed=1
        log "Removed managed block from $grub_default"
    fi
}

would_remove_managed_config() {
    local grub_default="/etc/default/grub"
    local dropin_file="/etc/default/grub.d/${THEME_NAME}-theme.cfg"

    [[ -d "$theme_dir" ]] && return 0
    [[ -f "$dropin_file" ]] && return 0
    [[ -f "$grub_default" ]] && grep -Fxq "$BEGIN_MARKER" "$grub_default"
}

run_mkconfig() {
    local command_path
    local grub_cfg

    if [[ "$changed" -eq 0 ]]; then
        log "No managed changes were found; skipping GRUB config regeneration."
        return 0
    fi

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
Uninstall plan:
  theme directory: $theme_dir
  managed drop-in: /etc/default/grub.d/${THEME_NAME}-theme.cfg
  managed block: /etc/default/grub between "$BEGIN_MARKER" and "$END_MARKER"
  mkconfig: $mkconfig_mode
PLAN

    if [[ "$apply" -eq 0 ]]; then
        cat <<'PLAN'

No changes were made. Re-run with --apply under sudo to remove managed files/config.
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

if [[ "$mkconfig_mode" == "auto" ]] && would_remove_managed_config; then
    find_mkconfig_command >/dev/null || die "could not find grub2-mkconfig, grub-mkconfig, or update-grub; use --mkconfig never to skip"
fi

print_plan
remove_theme_dir
remove_grub_config
run_mkconfig

log "minimal GRUB theme uninstalled."
